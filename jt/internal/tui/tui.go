// Package tui is the interactive face of jt: a board for browsing and managing
// tasks, and a queue for answering parked design forks. All rules live in core;
// nothing here touches jj except through it.
package tui

import (
	"fmt"
	"os"
	"os/exec"
	"slices"
	"strings"
	"time"

	"charm.land/bubbles/v2/textarea"
	"charm.land/bubbles/v2/textinput"
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

type row struct {
	header string
	count  int
	task   *core.Task
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

	rows       []row
	cursor     int
	listOff    int
	selected   string // id to hold across reloads
	filter     int
	search     string
	tab        int
	detailOff  int
	fullDetail bool
	cache      map[string][]string // tab|commit -> rendered lines

	mode      mode
	searchBox textinput.Model
	input     textinput.Model
	inputAsk  string
	inputDo   func(string) tea.Cmd
	pickAsk   string
	pickOpts  []string
	pickIdx   int
	pickDo    func(string) tea.Cmd
	askText   string
	askDo     func() tea.Cmd

	graph    []string
	graphOff int

	form newForm

	standaloneDecide bool
	decideSkipped    map[string]bool
	decideIdx        int
	decideText       textarea.Model
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
	return m
}

func lastPath(p string) string {
	if i := strings.LastIndexByte(p, '/'); i >= 0 {
		return p[i+1:]
	}
	return p
}

func (m *Model) Init() tea.Cmd { return tea.Batch(m.loadCmd(), tick()) }

func tick() tea.Cmd {
	return tea.Tick(2*time.Second, func(t time.Time) tea.Msg { return tickMsg(t) })
}

func (m *Model) loadCmd() tea.Cmd {
	repo := m.repo
	return func() tea.Msg {
		op, _ := repo.OpID()
		b, err := repo.Load()
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
	return func() tea.Msg {
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
	}
}

func (m *Model) current() *core.Task {
	if m.cursor >= 0 && m.cursor < len(m.rows) {
		return m.rows[m.cursor].task
	}
	return nil
}

// rebuild recomputes the visible rows, holding the selection across reloads.
func (m *Model) rebuild() {
	if m.board == nil {
		return
	}
	terms := strings.Fields(strings.ToLower(m.search))
	m.rows = m.rows[:0]
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
		if len(ts) == 0 {
			continue
		}
		m.rows = append(m.rows, row{header: lane.Name, count: len(ts)})
		for _, t := range ts {
			m.rows = append(m.rows, row{task: t})
		}
	}
	idx := slices.IndexFunc(m.rows, func(r row) bool { return r.task != nil && r.task.ID == m.selected })
	if idx < 0 {
		idx = min(m.cursor, len(m.rows)-1)
		if idx >= 0 && m.rows[idx].task == nil {
			if idx+1 < len(m.rows) {
				idx++
			}
		}
	}
	m.cursor = max(idx, 0)
	m.remember()
}

func (m *Model) remember() {
	if t := m.current(); t != nil {
		if m.selected != t.ID {
			m.detailOff = 0
		}
		m.selected = t.ID
	}
}

func (m *Model) move(delta int) {
	i := m.cursor
	for {
		i += delta
		if i < 0 || i >= len(m.rows) {
			return
		}
		if m.rows[i].task != nil {
			m.cursor = i
			m.remember()
			return
		}
	}
}

func (m *Model) jump(toEnd bool) {
	if len(m.rows) == 0 {
		return
	}
	if toEnd {
		m.cursor = len(m.rows)
		m.move(-1)
	} else {
		m.cursor = -1
		m.move(1)
	}
}

// Update is the top of the message loop.
func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.w, m.h = msg.Width, msg.Height
		m.form.resize(m.w, m.h)
		m.decideText.SetWidth(min(m.w-6, 90))
		m.decideText.SetHeight(5)
		return m, nil
	case tickMsg:
		return m, tea.Batch(tick(), m.opCmd())
	case opMsg:
		if string(msg) != m.opID {
			return m, m.loadCmd()
		}
		return m, nil
	case boardMsg:
		m.busy = false
		if msg.err != nil {
			m.setFlash(msg.err.Error(), true)
			return m, nil
		}
		m.board, m.opID, m.loaded = msg.board, msg.op, true
		m.rebuild()
		return m, m.ensureDetail()
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
		return m, m.loadCmd()
	case linesMsg:
		m.cache[msg.key] = msg.lines
		return m, nil
	case graphMsg:
		if msg.err != nil {
			m.mode = modeNormal
			m.setFlash(msg.err.Error(), true)
			return m, nil
		}
		m.graph = msg.lines
		return m, nil
	case editedMsg:
		return m, m.finishEdit(msg)
	case execDoneMsg:
		if msg.err != nil {
			m.setFlash(msg.err.Error(), true)
		}
		return m, m.loadCmd()
	case tea.KeyPressMsg:
		return m.key(msg)
	}
	return m.forward(msg)
}

// forward hands non-key messages (cursor blink) to whichever widget is focused.
func (m *Model) forward(msg tea.Msg) (tea.Model, tea.Cmd) {
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
	return m, cmd
}

func (m *Model) setFlash(s string, bad bool) {
	m.flash, m.flashBad = strings.ReplaceAll(s, "\n", " "), bad
}

func (m *Model) key(k tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	s := k.String()
	if s == "ctrl+c" {
		return m, tea.Quit
	}
	m.flash = "" // a flash lasts until the next keypress
	switch m.mode {
	case modeSearch:
		return m.keySearch(k)
	case modePicker:
		return m.keyPicker(s)
	case modeInput:
		return m.keyInput(k)
	case modeConfirm:
		return m.keyConfirm(s)
	case modeNew:
		return m.keyNew(k)
	case modeHelp:
		m.mode = modeNormal
		return m, nil
	case modeGraph:
		return m.keyGraph(s)
	case modeDecide:
		return m.keyDecide(s)
	case modeDecideText:
		return m.keyDecideText(k)
	}
	return m.keyNormal(s)
}

func (m *Model) keySearch(k tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		m.search = ""
		m.searchBox.SetValue("")
		m.mode = modeNormal
		m.rebuild()
		return m, nil
	case "enter":
		m.mode = modeNormal
		return m, m.ensureDetail()
	}
	var cmd tea.Cmd
	m.searchBox, cmd = m.searchBox.Update(k)
	m.search = m.searchBox.Value()
	m.rebuild()
	return m, cmd
}

func (m *Model) keyPicker(s string) (tea.Model, tea.Cmd) {
	switch s {
	case "esc", "q":
		m.mode = modeNormal
	case "j", "down":
		m.pickIdx = min(m.pickIdx+1, len(m.pickOpts)-1)
	case "k", "up":
		m.pickIdx = max(m.pickIdx-1, 0)
	case "enter":
		m.mode = modeNormal
		return m, m.pickDo(m.pickOpts[m.pickIdx])
	}
	return m, nil
}

func (m *Model) keyInput(k tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		m.mode = modeNormal
		if m.standaloneDecide || m.inputAsk == decideDeferAsk {
			m.mode = modeDecide
		}
		return m, nil
	case "enter":
		back := m.inputAsk == decideDeferAsk
		m.mode = modeNormal
		if back {
			m.mode = modeDecide
		}
		return m, m.inputDo(m.input.Value())
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	return m, cmd
}

func (m *Model) keyConfirm(s string) (tea.Model, tea.Cmd) {
	m.mode = modeNormal
	if s == "y" || s == "Y" || s == "enter" {
		return m, m.askDo()
	}
	return m, nil
}

func (m *Model) keyGraph(s string) (tea.Model, tea.Cmd) {
	page := max(m.h-3, 1)
	switch s {
	case "esc", "q", "v":
		m.mode = modeNormal
	case "j", "down":
		m.graphOff++
	case "k", "up":
		m.graphOff--
	case "ctrl+d", "pgdown", "space":
		m.graphOff += page
	case "ctrl+u", "pgup":
		m.graphOff -= page
	case "g", "home":
		m.graphOff = 0
	case "G", "end":
		m.graphOff = len(m.graph)
	}
	m.graphOff = max(min(m.graphOff, len(m.graph)-page), 0)
	return m, nil
}

func (m *Model) ask(prompt, initial string, do func(string) tea.Cmd) tea.Cmd {
	m.mode = modeInput
	m.inputAsk, m.inputDo = prompt, do
	m.input.SetValue(initial)
	m.input.CursorEnd()
	m.input.SetWidth(max(m.w-len(prompt)-6, 20))
	return m.input.Focus()
}

func (m *Model) pick(prompt string, opts []string, current string, do func(string) tea.Cmd) {
	m.mode = modePicker
	m.pickAsk, m.pickOpts, m.pickDo = prompt, opts, do
	m.pickIdx = max(slices.Index(opts, current), 0)
}

func (m *Model) confirm(prompt string, do func() tea.Cmd) {
	m.mode = modeConfirm
	m.askText, m.askDo = prompt, do
}

func (m *Model) keyNormal(s string) (tea.Model, tea.Cmd) {
	r := m.repo
	page := max(m.h-6, 1)
	// Navigation and view keys need no selection.
	switch s {
	case "q":
		return m, tea.Quit
	case "esc":
		if m.fullDetail {
			m.fullDetail = false
		} else if m.search != "" {
			m.search = ""
			m.searchBox.SetValue("")
			m.rebuild()
		}
		return m, nil
	case "j", "down":
		m.move(1)
		return m, m.ensureDetail()
	case "k", "up":
		m.move(-1)
		return m, m.ensureDetail()
	case "g", "home":
		m.jump(false)
		return m, m.ensureDetail()
	case "G", "end":
		m.jump(true)
		return m, m.ensureDetail()
	case "J", "ctrl+d", "pgdown":
		m.detailOff += page / 2
		return m, nil
	case "K", "ctrl+u", "pgup":
		m.detailOff = max(m.detailOff-page/2, 0)
		return m, nil
	case "tab", "l", "right":
		m.tab = (m.tab + 1) % len(tabs)
		m.detailOff = 0
		return m, m.ensureDetail()
	case "shift+tab", "h", "left":
		m.tab = (m.tab + len(tabs) - 1) % len(tabs)
		m.detailOff = 0
		return m, m.ensureDetail()
	case "enter":
		m.fullDetail = !m.fullDetail
		return m, nil
	case "f":
		m.filter = (m.filter + 1) % len(filters)
		m.rebuild()
		return m, m.ensureDetail()
	case "1", "2", "3", "4":
		m.filter = int(s[0] - '1')
		m.rebuild()
		return m, m.ensureDetail()
	case "/":
		m.mode = modeSearch
		m.searchBox.SetWidth(max(m.w/2-4, 20))
		return m, m.searchBox.Focus()
	case "?":
		m.mode = modeHelp
		return m, nil
	case "r":
		return m, m.loadCmd()
	case "n":
		m.mode = modeNew
		m.form = newNewForm(m.w, m.h)
		if t := m.current(); t != nil && t.Status != "done" {
			m.form.blockerHint = t.ID
		}
		return m, m.form.focus()
	case "v":
		m.mode = modeGraph
		m.graph, m.graphOff = nil, 0
		return m, m.graphCmd()
	case "B":
		m.mode = modeDecide
		m.decideSkipped = map[string]bool{}
		m.decideIdx = 0
		return m, nil
	case "O":
		cmd := exec.Command("jjui", "-r", core.GraphRevset())
		return m, tea.ExecProcess(cmd, func(err error) tea.Msg { return execDoneMsg{err} })
	case "u":
		m.confirm("Undo the last jj operation (in any workspace)?", func() tea.Cmd {
			return m.act(func() (*core.Result, error) {
				if err := r.Undo(); err != nil {
					return nil, err
				}
				return &core.Result{Note: "undid the last operation"}, nil
			})
		})
		return m, nil
	}

	t := m.current()
	if t == nil {
		return m, nil
	}
	id := t.ID
	switch s {
	case "y":
		m.setFlash("copied "+id, false)
		return m, tea.SetClipboard(id)
	case "s":
		m.pick("Status for "+id, core.Statuses, t.Status, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"status", v}}) })
		})
	case "p":
		m.pick("Priority for "+id, append(slices.Clone(core.Priorities), "none"), t.Priority, func(v string) tea.Cmd {
			if v == "none" {
				v = ""
			}
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"priority", v}}) })
		})
	case "o":
		return m, m.ask("Scope: ", t.Scope, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Set(id, [][2]string{{"scope", v}}) })
		})
	case "w":
		return m, m.ask("Waits on (ids or words, empty clears): ", t.Needs, func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.SetNeeds(id, strings.Fields(v), true) })
		})
	case "e":
		return m, m.editCmd(t)
	case "S":
		return m, m.act(func() (*core.Result, error) { return r.Start(id, core.StartOpts{}) })
	case "d", "a":
		return m, m.act(func() (*core.Result, error) { return r.Done(id) })
	case "b":
		return m, m.ask("Block "+id+", question: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Block(id, v, nil, 0) })
		})
	case "D":
		return m, m.ask("Defer "+id+", reason: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Defer(id, v) })
		})
	case "R":
		return m, m.ask("Reopen "+id+", why: ", "", func(v string) tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Reopen(id, v) })
		})
	case "x":
		m.confirm("Strip "+id+"'s trailers? It leaves the board for good.", func() tea.Cmd {
			return m.act(func() (*core.Result, error) { return r.Strip(id, "") })
		})
	}
	return m, nil
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
