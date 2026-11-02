// Package tui is the interactive face of jt: a board for browsing and managing
// tasks, and a queue for answering parked design forks. All rules live in core;
// nothing here touches jj except through it.
package tui

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"slices"
	"strings"
	"time"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	"charm.land/bubbles/v2/progress"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/textarea"
	"charm.land/bubbles/v2/textinput"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"

	"jt/internal/core"
)

// Screen selects what Run opens on.
type Screen int

const (
	ScreenBoard Screen = iota
	ScreenDecide
)

type mode int

const (
	modeNormal mode = iota
	modeSearch
	modePicker
	modeInput
	modeConfirm
	modeNew
	modeHelp
	modeGraph
	modeDecide
	modeDecideText
)

// Filters narrow the board. Lanes do the grouping; these answer "what am I here
// for" without scrolling past everything else.
var filters = []struct {
	name string
	keep func(*core.Task) bool
}{
	{"Open", func(t *core.Task) bool { return t.Status != "done" }},
	{"Ready", func(t *core.Task) bool { return t.Ready }},
	{"Needs you", func(t *core.Task) bool { return t.Status == "blocked" || t.Status == "testing" }},
	{"All", func(t *core.Task) bool { return true }},
}

var tabs = []string{"Details", "Trail", "Diff"}

// row is one line of the board list: a lane header, or a task under it.
type row struct {
	header string
	count  int
	task   *core.Task
	prefix string // tree connectors
}

func (r row) FilterValue() string { return "" } // jt's own search does the narrowing

// rowDelegate draws the board list.
type rowDelegate struct{}

func (rowDelegate) Height() int                         { return 1 }
func (rowDelegate) Spacing() int                        { return 0 }
func (rowDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }
func (rowDelegate) Render(w io.Writer, m list.Model, i int, it list.Item) {
	if r, ok := it.(row); ok {
		io.WriteString(w, rowLine(r, i == m.Index(), m.Width()))
	}
}

// pickItem is one option in the picker overlay.
type pickItem string

func (p pickItem) FilterValue() string { return "" }

type pickDelegate struct{}

func (pickDelegate) Height() int                         { return 1 }
func (pickDelegate) Spacing() int                        { return 0 }
func (pickDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }
func (pickDelegate) Render(w io.Writer, m list.Model, i int, it list.Item) {
	if p, ok := it.(pickItem); ok {
		io.WriteString(w, pickLine(string(p), i == m.Index(), m.Width()))
	}
}

// newList is a bubbles list stripped to the rows: jt draws its own frame around
// it and feeds it keys through its own keymap.
func newList(d list.ItemDelegate) list.Model {
	l := list.New(nil, d, 0, 0)
	l.SetShowTitle(false)
	l.SetShowFilter(false)
	l.SetShowStatusBar(false)
	l.SetShowPagination(false)
	l.SetShowHelp(false)
	l.SetFilteringEnabled(false)
	l.Paginator.ActiveDot = cyanStyle.Render("●")
	l.Paginator.InactiveDot = dimStyle.Render("·")
	return l
}

// Model is the whole TUI state.
type Model struct {
	repo     core.Repo
	template string
	repoName string
	w, h     int

	board  *core.Board
	opID   string
	loaded bool

	list     list.Model
	detail   viewport.Model
	help     help.Model
	spinner  spinner.Model
	bar      progress.Model
	spinning bool

	selected   string // id to hold across reloads
	lanes      bool   // group by lane rather than the dependency tree
	filter     int
	search     string
	tab        int
	fullDetail bool
	cache      map[string][]string // tab|commit -> rendered lines

	mode      mode
	searchBox textinput.Model
	input     textinput.Model
	inputAsk  string
	inputDo   func(string) tea.Cmd
	picker    list.Model
	pickAsk   string
	pickDo    func(string) tea.Cmd
	askText   string
	askDo     func() tea.Cmd

	graphView    viewport.Model
	graphLoading bool

	form newForm

	standaloneDecide bool
	decideSkipped    map[string]bool
	decideIdx        int
	decideText       textarea.Model
	decideView       viewport.Model
	decideShown      string // the task decideView is showing
	decideMoot       bool
	decidedCount     int
	decidePending    bool

	flash    string
	flashBad bool
	busy     bool
}

type (
	boardMsg struct {
		board *core.Board
		op    string
		err   error
	}
	opMsg     string
	tickMsg   time.Time
	actionMsg struct {
		note  string
		warns []string
		err   error
		sel   string
	}
	linesMsg struct {
		key   string
		lines []string
	}
	graphMsg struct {
		lines []string
		err   error
	}
	editedMsg struct {
		id, path, before string
		err              error
	}
	execDoneMsg struct{ err error }
)

// Run starts the TUI on a screen.
func Run(repo core.Repo, screen Screen, template string) error {
	m := newModel(repo, screen, template)
	_, err := tea.NewProgram(m).Run()
	return err
}

func newModel(repo core.Repo, screen Screen, template string) *Model {
	root, _ := repo.Root()
	m := &Model{
		repo: repo, template: template, repoName: lastPath(root), w: 100, h: 30,
		cache: map[string][]string{}, decideSkipped: map[string]bool{},
	}
	m.list = newList(rowDelegate{})
	m.picker = newList(pickDelegate{})
	m.detail = viewport.New()
	m.graphView = viewport.New()
	m.decideView = viewport.New()
	m.help = help.New()
	m.help.Styles = help.Styles{
		Ellipsis: dimStyle, ShortKey: cyanStyle, ShortDesc: dimStyle, ShortSeparator: dimStyle,
		FullKey: cyanStyle, FullDesc: dimStyle, FullSeparator: dimStyle,
	}
	m.help.ShortSeparator = "  "
	m.spinner = spinner.New(spinner.WithSpinner(spinner.MiniDot), spinner.WithStyle(cyanStyle))
	m.bar = progress.New(progress.WithWidth(14), progress.WithoutPercentage(),
		progress.WithFillCharacters('█', '░'), progress.WithColors(greenColor))
	m.bar.EmptyColor = dimColor
	m.searchBox = textinput.New()
	m.searchBox.Prompt = "/"
	m.input = textinput.New()
	m.decideText = textarea.New()
	m.decideText.ShowLineNumbers = false
	m.form = newNewForm(m.w, m.h)
	if screen == ScreenDecide {
		m.mode = modeDecide
		m.standaloneDecide = true
	}
	m.sync()
	return m
}

func lastPath(p string) string {
	if i := strings.LastIndexByte(p, '/'); i >= 0 {
		return p[i+1:]
	}
	return p
}

func (m *Model) Init() tea.Cmd { return tea.Batch(m.loadCmd(), tick(), m.spin()) }

func tick() tea.Cmd {
	return tea.Tick(2*time.Second, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// spin starts the spinner if it isn't already going. It stops itself once nothing
// is pending.
func (m *Model) spin() tea.Cmd {
	if m.spinning {
		return nil
	}
	m.spinning = true
	return m.spinner.Tick
}

func (m *Model) loadCmd() tea.Cmd {
	repo := m.repo
	return func() tea.Msg {
		op, _ := repo.OpID()
		b, err := repo.Load()
		if err == nil {
			repo.FillStats(b) // decoration: a board without stats still works
		}
		return boardMsg{b, op, err}
	}
}

func (m *Model) opCmd() tea.Cmd {
	repo := m.repo
	return func() tea.Msg {
		op, err := repo.OpID()
		if err != nil {
			return nil
		}
		return opMsg(op)
	}
}

// act runs a mutation off the UI thread, reporting through a flash.
func (m *Model) act(do func() (*core.Result, error)) tea.Cmd {
	m.busy = true
	return tea.Batch(func() tea.Msg {
		res, err := do()
		if err != nil {
			return actionMsg{err: err}
		}
		msg := actionMsg{note: res.Note, warns: res.Warnings}
		if res.Task != nil {
			msg.note = res.Task.ID + " " + res.Note
			msg.sel = res.Task.ID
		}
		return msg
	}, m.spin())
}

func (m *Model) current() *core.Task {
	if r, ok := m.list.SelectedItem().(row); ok {
		return r.task
	}
	return nil
}

// rebuild recomputes the visible rows, holding the selection across reloads.
func (m *Model) rebuild() {
	if m.board == nil {
		return
	}
	cursor := m.list.Index()
	terms := strings.Fields(strings.ToLower(m.search))
	rows := []list.Item{}
	var visible []*core.Task
	for _, lane := range m.board.Lanes() {
		var ts []*core.Task
		for _, t := range lane.Tasks {
			if !filters[m.filter].keep(t) {
				continue
			}
			hay := strings.ToLower(t.ID + " " + t.Status + " " + t.Priority + " " + t.Summary + " " + t.Scope)
			if slices.ContainsFunc(terms, func(s string) bool { return !strings.Contains(hay, s) }) {
				continue
			}
			ts = append(ts, t)
		}
		visible = append(visible, ts...)
		if m.lanes && len(ts) > 0 {
			rows = append(rows, row{header: lane.Name, count: len(ts)})
			for _, t := range ts {
				rows = append(rows, row{task: t})
			}
		}
	}
	if !m.lanes {
		rows = treeRows(m.board, visible)
	}
	m.list.SetItems(rows)
	idx := slices.IndexFunc(rows, func(it list.Item) bool {
		r := it.(row)
		return r.task != nil && r.task.ID == m.selected
	})
	if idx < 0 {
		idx = min(cursor, len(rows)-1)
		if idx >= 0 && rows[idx].(row).task == nil && idx+1 < len(rows) {
			idx++
		}
	}
	m.list.Select(max(idx, 0))
	m.remember()
}

// treeRows lays tasks out by dependency, in the order given (which is the order
// roots and siblings appear in). A task hangs off its first visible ancestor, so a
// filtered-out parent doesn't orphan its children. Only real branches indent: a
// stack of tasks stays in one column, the way jj draws it, rather than marching
// off the right edge.
func treeRows(b *core.Board, tasks []*core.Task) []list.Item {
	visible := map[string]bool{}
	for _, t := range tasks {
		visible[t.ID] = true
	}
	var ancestor func(t *core.Task, seen map[string]bool) string
	ancestor = func(t *core.Task, seen map[string]bool) string {
		for _, id := range t.Parents {
			if visible[id] {
				return id
			}
		}
		for _, id := range t.Parents {
			if p := b.ByID[id]; p != nil && !seen[id] {
				seen[id] = true
				if a := ancestor(p, seen); a != "" {
					return a
				}
			}
		}
		return ""
	}
	children := map[string][]*core.Task{}
	var roots []*core.Task
	for _, t := range tasks {
		if a := ancestor(t, map[string]bool{}); a != "" {
			children[a] = append(children[a], t)
		} else {
			roots = append(roots, t)
		}
	}
	rows := []list.Item{}
	var walk func(t *core.Task, prefix, slot string)
	walk = func(t *core.Task, prefix, slot string) {
		rows = append(rows, row{task: t, prefix: prefix + slot})
		switch slot {
		case "├ ":
			prefix += "│ "
		case "└ ":
			prefix += "  "
		}
		kids := children[t.ID]
		if len(kids) == 1 {
			walk(kids[0], prefix, "↳ ")
			return
		}
		for i, k := range kids {
			if i == len(kids)-1 {
				walk(k, prefix, "└ ")
			} else {
				walk(k, prefix, "├ ")
			}
		}
	}
	for _, t := range roots {
		walk(t, "", "")
	}
	return rows
}

func (m *Model) remember() {
	if t := m.current(); t != nil {
		if m.selected != t.ID {
			m.detail.GotoTop()
		}
		m.selected = t.ID
	}
}

// moveFrom walks to the next task row, stepping over lane headers.
func (m *Model) moveFrom(i, delta int) {
	items := m.list.Items()
	for {
		i += delta
		if i < 0 || i >= len(items) {
			return
		}
		if items[i].(row).task != nil {
			m.list.Select(i)
			m.remember()
			return
		}
	}
}

func (m *Model) move(delta int) { m.moveFrom(m.list.Index(), delta) }

func (m *Model) jump(toEnd bool) {
	if toEnd {
		m.moveFrom(len(m.list.Items()), -1)
	} else {
		m.moveFrom(-1, 1)
	}
}

// boardWidths splits the terminal between the list and the detail pane.
func (m *Model) boardWidths() (list, detail int) {
	switch {
	case m.fullDetail:
		return 0, m.w
	case m.w < 90:
		return m.w, 0
	}
	list = max(m.w*55/100, 50)
	return list, m.w - list
}

// sync pushes sizes and content into the widgets. It runs after every message, so
// View only has to draw them.
func (m *Model) sync() {
	innerH := max(m.h-5, 0) // header, filter bar, footer, and the frame's two edges
	lw, dw := m.boardWidths()
	m.list.SetSize(max(lw-2, 0), innerH)
	m.detail.SetWidth(max(dw-4, 0))
	m.detail.SetHeight(innerH)
	m.detail.SetContentLines(m.detailContent(max(dw-4, 1)))
	m.graphView.SetWidth(max(m.w-4, 0))
	m.graphView.SetHeight(max(m.h-3, 0))
	m.picker.SetSize(modalWidth(m.w, 44)-4, min(len(m.picker.Items()), max(m.h-6, 1)))
	m.help.SetWidth(max(m.w-2, 0))
	m.syncDecide()
}

// Update is the top of the message loop.
func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	cmd := m.update(msg)
	m.sync()
	return m, cmd
}

func (m *Model) update(msg tea.Msg) tea.Cmd {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.w, m.h = msg.Width, msg.Height
		m.form.resize(m.w, m.h)
		m.decideText.SetWidth(max(min(m.w-6, 90), 20))
		m.decideText.SetHeight(5)
		return nil
	case tickMsg:
		return tea.Batch(tick(), m.opCmd())
	case opMsg:
		if string(msg) != m.opID {
			return m.loadCmd()
		}
		return nil
	case spinner.TickMsg:
		if !m.busy && m.loaded && !m.graphLoading {
			m.spinning = false
			return nil
		}
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return cmd
	case boardMsg:
		m.busy = false
		if msg.err != nil {
			m.setFlash(msg.err.Error(), true)
			return nil
		}
		m.board, m.opID, m.loaded = msg.board, msg.op, true
		m.rebuild()
		return m.ensureDetail()
	case actionMsg:
		m.busy = false
		if m.decidePending && msg.err == nil {
			m.decidedCount++
		}
		m.decidePending = false
		switch {
		case msg.err != nil:
			m.setFlash(msg.err.Error(), true)
		case len(msg.warns) > 0:
			m.setFlash(msg.note+" — "+strings.Join(msg.warns, "; "), true)
		default:
			m.setFlash(msg.note, false)
		}
		if msg.sel != "" {
			m.selected = msg.sel
		}
		return m.loadCmd()
	case linesMsg:
		m.cache[msg.key] = msg.lines
		return nil
	case graphMsg:
		m.graphLoading = false
		if msg.err != nil {
			m.mode = modeNormal
			m.setFlash(msg.err.Error(), true)
			return nil
		}
		m.graphView.SetContentLines(msg.lines)
		return nil
	case editedMsg:
		return m.finishEdit(msg)
	case execDoneMsg:
		if msg.err != nil {
			m.setFlash(msg.err.Error(), true)
		}
		return m.loadCmd()
	case tea.KeyPressMsg:
		return m.key(msg)
	}
	return m.forward(msg)
}

// forward hands non-key messages (cursor blink) to whichever widget is focused.
func (m *Model) forward(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	switch m.mode {
	case modeSearch:
		m.searchBox, cmd = m.searchBox.Update(msg)
	case modeInput:
		m.input, cmd = m.input.Update(msg)
	case modeNew:
		cmd = m.form.update(msg)
	case modeDecideText:
		m.decideText, cmd = m.decideText.Update(msg)
	}
	return cmd
}

func (m *Model) setFlash(s string, bad bool) {
	m.flash, m.flashBad = strings.ReplaceAll(s, "\n", " "), bad
}

func (m *Model) key(k tea.KeyPressMsg) tea.Cmd {
	if k.String() == "ctrl+c" {
		return tea.Quit
	}
	m.flash = "" // a flash lasts until the next keypress
	switch m.mode {
	case modeSearch:
		return m.keySearch(k)
	case modePicker:
		return m.keyPicker(k)
	case modeInput:
		return m.keyInput(k)
	case modeConfirm:
		return m.keyConfirm(k)
	case modeNew:
		return m.keyNew(k)
	case modeHelp:
		m.mode = modeNormal
		return nil
	case modeGraph:
		return m.keyGraph(k)
	case modeDecide:
		return m.keyDecide(k)
	case modeDecideText:
		return m.keyDecideText(k)
	}
	return m.keyNormal(k)
}

func (m *Model) keySearch(k tea.KeyPressMsg) tea.Cmd {
	switch k.String() {
	case "esc":
		m.search = ""
		m.searchBox.SetValue("")
		m.mode = modeNormal
		m.rebuild()
		return nil
	case "enter":
		m.mode = modeNormal
		return m.ensureDetail()
	}
	var cmd tea.Cmd
	m.searchBox, cmd = m.searchBox.Update(k)
	m.search = m.searchBox.Value()
	m.rebuild()
	return cmd
}

func (m *Model) keyPicker(k tea.KeyPressMsg) tea.Cmd {
	switch {
	case key.Matches(k, keys.Esc, keys.Quit):
		m.mode = modeNormal
	case key.Matches(k, keys.Down):
		m.picker.CursorDown()
	case key.Matches(k, keys.Up):
		m.picker.CursorUp()
	case key.Matches(k, keys.Enter):
		m.mode = modeNormal
		if p, ok := m.picker.SelectedItem().(pickItem); ok {
			return m.pickDo(string(p))
		}
	}
	return nil
}

func (m *Model) keyInput(k tea.KeyPressMsg) tea.Cmd {
	switch k.String() {
	case "esc":
		m.mode = modeNormal
		if m.standaloneDecide || m.inputAsk == decideDeferAsk {
			m.mode = modeDecide
		}
		return nil
	case "enter":
		back := m.inputAsk == decideDeferAsk
		m.mode = modeNormal
		if back {
			m.mode = modeDecide
		}
		return m.inputDo(m.input.Value())
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	return cmd
}

func (m *Model) keyConfirm(k tea.KeyPressMsg) tea.Cmd {
	m.mode = modeNormal
	switch k.String() {
	case "y", "Y", "enter":
		return m.askDo()
	}
	return nil
}

func (m *Model) keyGraph(k tea.KeyPressMsg) tea.Cmd {
	v := &m.graphView
	switch {
	case key.Matches(k, keys.Esc, keys.Quit, keys.Graph):
		m.mode = modeNormal
	case key.Matches(k, keys.Down):
		v.ScrollDown(1)
	case key.Matches(k, keys.Up):
		v.ScrollUp(1)
	case key.Matches(k, keys.PageDown):
		v.PageDown()
	case key.Matches(k, keys.PageUp):
		v.PageUp()
	case key.Matches(k, keys.First):
		v.GotoTop()
	case key.Matches(k, keys.Last):
		v.GotoBottom()
	case key.Matches(k, keys.Left):
		v.ScrollLeft(6)
	case key.Matches(k, keys.Right):
		v.ScrollRight(6)
	}
	return nil
}

func (m *Model) ask(prompt, initial string, do func(string) tea.Cmd) tea.Cmd {
	m.mode = modeInput
	m.inputAsk, m.inputDo = prompt, do
	m.input.SetValue(initial)
	m.input.CursorEnd()
	m.input.SetWidth(max(modalWidth(m.w, 70)-8, 10))
	return m.input.Focus()
}

func (m *Model) pick(prompt string, opts []string, current string, do func(string) tea.Cmd) {
	m.mode = modePicker
	m.pickAsk, m.pickDo = prompt, do
	items := make([]list.Item, len(opts))
	for i, o := range opts {
		items[i] = pickItem(o)
	}
	m.picker.SetItems(items)
	m.picker.SetSize(modalWidth(m.w, 44)-4, min(len(items), max(m.h-6, 1)))
	m.picker.Select(max(slices.Index(opts, current), 0))
}

func (m *Model) confirm(prompt string, do func() tea.Cmd) {
	m.mode = modeConfirm
	m.askText, m.askDo = prompt, do
}

func (m *Model) keyNormal(k tea.KeyPressMsg) tea.Cmd {
	r := m.repo
	// Navigation and view keys need no selection.
	switch {
	case key.Matches(k, keys.Quit):
		return tea.Quit
	case key.Matches(k, keys.Esc):
		if m.fullDetail {
			m.fullDetail = false
		} else if m.search != "" {
			m.search = ""
			m.searchBox.SetValue("")
			m.rebuild()
		}
		return nil
	case key.Matches(k, keys.Down):
		m.move(1)
		return m.ensureDetail()
	case key.Matches(k, keys.Up):
		m.move(-1)
		return m.ensureDetail()
	case key.Matches(k, keys.First):
		m.jump(false)
		return m.ensureDetail()
	case key.Matches(k, keys.Last):
		m.jump(true)
		return m.ensureDetail()
	case key.Matches(k, keys.ScrollDown):
		m.detail.HalfPageDown()
		return nil
	case key.Matches(k, keys.ScrollUp):
		m.detail.HalfPageUp()
		return nil
	case key.Matches(k, keys.NextTab):
		m.tab = (m.tab + 1) % len(tabs)
		m.detail.GotoTop()
		return m.ensureDetail()
	case key.Matches(k, keys.PrevTab):
		m.tab = (m.tab + len(tabs) - 1) % len(tabs)
		m.detail.GotoTop()
		return m.ensureDetail()
	case key.Matches(k, keys.Full):
		m.fullDetail = !m.fullDetail
		return nil
	case key.Matches(k, keys.Tree):
		m.lanes = !m.lanes
		m.rebuild()
		return m.ensureDetail()
	case key.Matches(k, keys.Filter):
		m.filter = (m.filter + 1) % len(filters)
		m.rebuild()
		return m.ensureDetail()
	case key.Matches(k, keys.FilterN):
		m.filter = int(k.String()[0] - '1')
		m.rebuild()
		return m.ensureDetail()
	case key.Matches(k, keys.Search):
		m.mode = modeSearch
		m.searchBox.SetWidth(max(m.w/2-4, 20))
		return m.searchBox.Focus()
	case key.Matches(k, keys.Help):
		m.mode = modeHelp
		return nil
	case key.Matches(k, keys.Refresh):
		return m.loadCmd()
	case key.Matches(k, keys.New):
		m.mode = modeNew
		m.form = newNewForm(m.w, m.h)
		if t := m.current(); t != nil && t.Status != "done" {
			m.form.blockerHint = t.ID
		}
		return m.form.focus()
	case key.Matches(k, keys.Graph):
		m.mode = modeGraph
		m.graphLoading = true
		m.graphView.SetContentLines(nil)
		m.graphView.GotoTop()
		m.graphView.SetXOffset(0)
		return tea.Batch(m.graphCmd(), m.spin())
	case key.Matches(k, keys.Decide):
		m.mode = modeDecide
		m.decideSkipped = map[string]bool{}
		m.decideIdx = 0
		return nil
	case key.Matches(k, keys.Jjui):
		cmd := exec.Command("jjui", "-r", core.GraphRevset())
		return tea.ExecProcess(cmd, func(err error) tea.Msg { return execDoneMsg{err} })
	case key.Matches(k, keys.Undo):
		m.confirm("Undo the last jj operation (in any workspace)?", func() tea.Cmd {
			return m.act(func() (*core.Result, error) {
				if err := r.Undo(); err != nil {
					return nil, err
				}
				return &core.Result{Note: "undid the last operation"}, nil
			})
		})
		return nil
	}

	t := m.current()
	if t == nil {
		return nil
	}
	id := t.ID
	switch {
	case key.Matches(k, keys.Copy):
		m.setFlash("copied "+id, false)
		return tea.SetClipboard(id)
	case key.Matches(k, keys.Status):
		m.pick("Status for "+id, core.Statuses, t.Status, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"status", v}}) })
		})
	case key.Matches(k, keys.Prio):
		m.pick("Priority for "+id, append(slices.Clone(core.Priorities), "none"), t.Priority, func(v string) tea.Cmd {
			if v == "none" {
				v = ""
			}
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"priority", v}}) })
		})
	case key.Matches(k, keys.Scope):
		return m.ask("Scope: ", t.Scope, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"scope", v}}) })
		})
	case key.Matches(k, keys.Waits):
		return m.ask("Waits on (ids or words, empty clears): ", t.Needs, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.SetNeeds(id, strings.Fields(v), true) })
		})
	case key.Matches(k, keys.Edit):
		return m.editCmd(t)
	case key.Matches(k, keys.Start):
		return m.act(func() (*core.Result, error) { return r.Start(id, core.StartOpts{}) })
	case key.Matches(k, keys.Done, keys.Accept):
		return m.act(func() (*core.Result, error) { return r.Done(id) })
	case key.Matches(k, keys.Block):
		return m.ask("Block "+id+", question: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Block(id, v, nil, 0) })
		})
	case key.Matches(k, keys.Defer):
		return m.ask("Defer "+id+", reason: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Defer(id, v) })
		})
	case key.Matches(k, keys.Reopen):
		return m.ask("Reopen "+id+", why: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Reopen(id, v) })
		})
	case key.Matches(k, keys.Strip):
		m.confirm("Strip "+id+"'s trailers? It leaves the board for good.", func() tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Strip(id, "") })
		})
	}
	return nil
}

// editCmd opens the message above the trailers in $EDITOR. The trailer block isn't
// in the file: it's jt's state, and there's nothing there a person should hand-edit.
func (m *Model) editCmd(t *core.Task) tea.Cmd {
	f, err := os.CreateTemp("", "jt-"+t.ID+"-*.md")
	if err != nil {
		m.setFlash(err.Error(), true)
		return nil
	}
	before := t.Msg.Above() + "\n"
	f.WriteString(before)
	f.Close()
	path, id := f.Name(), t.ID
	cmd := exec.Command("sh", "-c", `exec ${VISUAL:-${EDITOR:-vi}} "$0"`, path)
	return tea.ExecProcess(cmd, func(err error) tea.Msg { return editedMsg{id, path, before, err} })
}

func (m *Model) finishEdit(e editedMsg) tea.Cmd {
	defer os.Remove(e.path)
	if e.err != nil {
		m.setFlash(fmt.Sprintf("editor: %v", e.err), true)
		return nil
	}
	data, err := os.ReadFile(e.path)
	if err != nil {
		m.setFlash(err.Error(), true)
		return nil
	}
	after := string(data)
	if after == e.before || strings.TrimSpace(after) == "" {
		m.setFlash("no change", false)
		return nil
	}
	r, id := m.repo, e.id
	return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"message", after}}) })
}

// ensureDetail loads what the current tab needs, once per commit.
func (m *Model) ensureDetail() tea.Cmd {
	t := m.current()
	if t == nil || m.tab == 0 {
		return nil
	}
	key := detailKey(m.tab, t)
	if _, ok := m.cache[key]; ok {
		return nil
	}
	m.cache[key] = []string{dimStyle.Render("loading…")}
	repo, id, tab := m.repo, t.ID, m.tab
	return func() tea.Msg {
		if tab == 1 {
			return linesMsg{key, renderTrail(repo, id)}
		}
		return linesMsg{key, renderDiff(repo, id)}
	}
}

func detailKey(tab int, t *core.Task) string { return fmt.Sprintf("%d|%s", tab, t.CommitID) }

func (m *Model) graphCmd() tea.Cmd {
	repo, tmpl := m.repo, m.template
	return func() tea.Msg {
		out, err := repo.Graph(tmpl, true)
		return graphMsg{strings.Split(strings.TrimRight(out, "\n"), "\n"), err}
	}
}
