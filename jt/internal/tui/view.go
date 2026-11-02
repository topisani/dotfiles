package tui

import (
	"fmt"
	"slices"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"jt/internal/core"
)

// ANSI palette only: this follows whatever theme the terminal has, which matters
// on a machine with a colorscheme switcher.
var (
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.BrightBlack)
	boldStyle   = lipgloss.NewStyle().Bold(true)
	idStyle     = lipgloss.NewStyle().Foreground(lipgloss.Yellow)
	prioStyle   = lipgloss.NewStyle().Foreground(lipgloss.Magenta)
	cyanStyle   = lipgloss.NewStyle().Foreground(lipgloss.Cyan)
	redStyle    = lipgloss.NewStyle().Foreground(lipgloss.Red)
	greenStyle  = lipgloss.NewStyle().Foreground(lipgloss.Green)
	selStyle    = lipgloss.NewStyle().Reverse(true)
	laneStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Blue)
	activeStyle = lipgloss.NewStyle().Bold(true).Underline(true)
	titleStyle  = lipgloss.NewStyle().Bold(true).Reverse(true).Padding(0, 1)
)

var statusStyles = map[string]lipgloss.Style{
	"todo":          lipgloss.NewStyle().Foreground(lipgloss.Blue),
	"ready":         lipgloss.NewStyle().Foreground(lipgloss.BrightBlue),
	"doing":         lipgloss.NewStyle().Foreground(lipgloss.Green),
	"investigating": lipgloss.NewStyle().Foreground(lipgloss.Magenta),
	"blocked":       lipgloss.NewStyle().Foreground(lipgloss.BrightRed),
	"testing":       lipgloss.NewStyle().Foreground(lipgloss.BrightYellow),
	"deferred":      lipgloss.NewStyle().Foreground(lipgloss.White),
	"done":          dimStyle,
}

var statusGlyphs = map[string]string{
	"todo": "○", "ready": "◎", "doing": "●", "investigating": "◐",
	"blocked": "✖", "testing": "◆", "deferred": "◌", "done": "✓",
}

func statusStyle(s string) lipgloss.Style {
	if st, ok := statusStyles[s]; ok {
		return st
	}
	return redStyle
}

func glyph(s string) string {
	if g, ok := statusGlyphs[s]; ok {
		return g
	}
	return "?"
}

// fit truncates or pads one line to exactly w cells.
func fit(s string, w int) string {
	if w <= 0 {
		return ""
	}
	s = ansi.Truncate(s, w, "…")
	if pad := w - lipgloss.Width(s); pad > 0 {
		s += strings.Repeat(" ", pad)
	}
	return s
}

// View draws the current mode.
func (m *Model) View() tea.View {
	var s string
	switch {
	case m.mode == modeDecide, m.mode == modeDecideText, m.mode == modeInput && m.inputAsk == decideDeferAsk:
		s = m.viewDecide()
	case m.mode == modeNew:
		s = m.viewNew()
	case m.mode == modeHelp:
		s = m.viewHelp()
	case m.mode == modeGraph:
		s = m.viewGraph()
	default:
		s = m.viewBoard()
	}
	v := tea.NewView(s)
	v.AltScreen = true
	return v
}

func (m *Model) viewBoard() string {
	bodyH := max(m.h-3, 1)
	var body []string
	switch {
	case !m.loaded:
		body = []string{dimStyle.Render(" loading…")}
	case m.fullDetail:
		body = m.detailPane(m.w, bodyH)
	case m.w < 90:
		body = m.listPane(m.w, bodyH)
	default:
		lw := max(m.w*45/100, 40)
		dw := m.w - lw - 1
		left := m.listPane(lw, bodyH)
		right := m.detailPane(dw, bodyH)
		sep := dimStyle.Render("│")
		for i := 0; i < bodyH; i++ {
			l, r := "", ""
			if i < len(left) {
				l = left[i]
			}
			if i < len(right) {
				r = right[i]
			}
			body = append(body, fit(l, lw)+sep+fit(r, dw))
		}
	}
	for len(body) < bodyH {
		body = append(body, "")
	}
	lines := append([]string{fit(m.header(), m.w), fit(m.filterBar(), m.w)}, body[:bodyH]...)
	lines = append(lines, fit(m.footer(), m.w))
	return strings.Join(lines, "\n")
}

func (m *Model) header() string {
	var chips []string
	if m.board != nil {
		counts := map[string]int{}
		for _, t := range m.board.Tasks {
			counts[t.Status]++
		}
		for _, st := range core.Statuses {
			if n := counts[st]; n > 0 {
				chips = append(chips, statusStyle(st).Render(fmt.Sprintf("%s %d %s", glyph(st), n, st)))
			}
		}
	}
	title := titleStyle.Render("jt " + m.repoName)
	line := title + " " + strings.Join(chips, "  ")
	if m.busy {
		line += "  " + dimStyle.Render("working…")
	}
	return line
}

func (m *Model) filterBar() string {
	var parts []string
	for i, f := range filters {
		label := fmt.Sprintf("%d %s", i+1, f.name)
		if i == m.filter {
			parts = append(parts, activeStyle.Render(label))
		} else {
			parts = append(parts, dimStyle.Render(label))
		}
	}
	line := " " + strings.Join(parts, "  ")
	if m.mode == modeSearch {
		line += "   " + m.searchBox.View()
	} else if m.search != "" {
		line += "   " + cyanStyle.Render("/"+m.search)
	}
	return line
}

func (m *Model) footer() string {
	switch m.mode {
	case modePicker:
		return ""
	case modeConfirm:
		return boldStyle.Render(m.askText) + dimStyle.Render("  y/n")
	case modeInput:
		return boldStyle.Render(m.inputAsk) + m.input.View()
	}
	if m.flash != "" {
		if m.flashBad {
			return redStyle.Render(" " + m.flash)
		}
		return greenStyle.Render(" " + m.flash)
	}
	hints := "j/k move  tab pane  / search  f filter  n new  S start  s status  p prio  e edit  d done  B decide  v graph  ? help  q quit"
	if t := m.current(); t != nil && t.Status == "testing" {
		hints = "a accept  R reopen  " + hints
	}
	return dimStyle.Render(" " + hints)
}

func (m *Model) listPane(w, h int) []string {
	if m.mode == modePicker {
		return m.pickerLines(w, h)
	}
	if len(m.rows) == 0 {
		msg := "nothing here"
		if m.board != nil && len(m.board.Tasks) == 0 {
			msg = "no tasks yet: press n to file one"
		}
		return []string{dimStyle.Render(" " + msg)}
	}
	// Keep the cursor visible, and its lane header with it when there's room.
	if m.cursor < m.listOff {
		m.listOff = m.cursor
		if m.listOff > 0 && m.rows[m.listOff-1].task == nil {
			m.listOff--
		}
	}
	if m.cursor >= m.listOff+h {
		m.listOff = m.cursor - h + 1
	}
	m.listOff = max(min(m.listOff, len(m.rows)-h), 0)
	var out []string
	for i := m.listOff; i < len(m.rows) && len(out) < h; i++ {
		out = append(out, m.rowLine(m.rows[i], i == m.cursor, w))
	}
	return out
}

func (m *Model) rowLine(r row, selected bool, w int) string {
	if r.task == nil {
		return " " + laneStyle.Render(r.header) + dimStyle.Render(fmt.Sprintf(" %d", r.count))
	}
	t := r.task
	prio := t.Priority
	if prio == "" {
		prio = "  "
	}
	mark := ""
	switch {
	case t.Conflict:
		mark = " !conflict"
	case t.Orphaned:
		mark = " !orphaned"
	case t.Status == "doing" && len(t.Workspaces) > 0:
		mark = " @" + strings.Join(t.Workspaces, ",")
	case t.Needs != "":
		mark = fmt.Sprintf(" ⇢%d", len(t.NeedsList()))
	case len(t.Collides) > 0:
		mark = " ⚠scope"
	}
	if selected {
		return selStyle.Render(fit(fmt.Sprintf(" %s %s %s %s%s", t.ID, glyph(t.Status), prio, t.Summary, mark), w))
	}
	summaryW := max(w-lipgloss.Width(t.ID)-lipgloss.Width(prio)-lipgloss.Width(mark)-6, 4)
	summary := ansi.Truncate(t.Summary, summaryW, "…")
	if t.Status == "done" || t.Status == "deferred" {
		summary = dimStyle.Render(summary)
	}
	markStyled := cyanStyle.Render(mark)
	if t.Conflict || t.Orphaned {
		markStyled = redStyle.Render(mark)
	}
	return " " + idStyle.Render(t.ID) + " " + statusStyle(t.Status).Render(glyph(t.Status)) + " " + prioStyle.Render(prio) + " " + summary + markStyled
}

func (m *Model) pickerLines(w, h int) []string {
	out := []string{" " + boldStyle.Render(m.pickAsk), ""}
	for i, o := range m.pickOpts {
		label := " " + glyph(o) + " " + o
		if _, known := statusGlyphs[o]; !known {
			label = "   " + o
		} else {
			label = " " + statusStyle(o).Render(glyph(o)) + " " + o
		}
		if i == m.pickIdx {
			out = append(out, selStyle.Render(fit(ansi.Strip(label), w)))
		} else {
			out = append(out, label)
		}
	}
	out = append(out, "", dimStyle.Render(" enter choose  esc cancel"))
	return out
}

func (m *Model) detailPane(w, h int) []string {
	t := m.current()
	if t == nil {
		return nil
	}
	var parts []string
	for i, name := range tabs {
		if i == m.tab {
			parts = append(parts, activeStyle.Render(name))
		} else {
			parts = append(parts, dimStyle.Render(name))
		}
	}
	head := " " + strings.Join(parts, "  ")
	var lines []string
	if m.tab == 0 {
		lines = m.detailLines(t, w-2)
	} else {
		for _, l := range m.cache[detailKey(m.tab, t)] {
			lines = append(lines, strings.Split(ansi.Wrap(l, w-2, ""), "\n")...)
		}
	}
	m.detailOff = max(min(m.detailOff, len(lines)-(h-1)), 0)
	out := []string{head}
	for i := m.detailOff; i < len(lines) && len(out) < h; i++ {
		out = append(out, " "+lines[i])
	}
	return out
}

func (m *Model) detailLines(t *core.Task, w int) []string {
	var out []string
	add := func(s string) { out = append(out, strings.Split(ansi.Wrap(s, w, ""), "\n")...) }
	field := func(k, v string) { add(dimStyle.Render(fmt.Sprintf("%-10s", k)) + v) }

	add(boldStyle.Render(t.Summary))
	out = append(out, "")
	status := statusStyle(t.Status).Render(glyph(t.Status) + " " + t.Status)
	if t.Priority != "" {
		status += "  " + prioStyle.Render(t.Priority)
	}
	if t.Ready {
		status += "  " + greenStyle.Render("ready")
	}
	field("status", status)
	field("id", idStyle.Render(t.ID)+dimStyle.Render(" "+t.CommitID))
	if t.Scope != "" {
		field("scope", t.Scope)
	}
	if len(t.Workspaces) > 0 {
		field("@ of", strings.Join(t.Workspaces, ", "))
	}
	if t.Needs != "" {
		for _, id := range t.NeedsList() {
			summary := ""
			if b := m.board.ByID[id]; b != nil {
				summary = b.Summary
			}
			field("needs", idStyle.Render(id)+" "+summary)
		}
	}
	if m.board != nil {
		for _, d := range m.board.Dependents(t.ID) {
			field("blocks", idStyle.Render(d.ID)+" "+d.Summary)
		}
	}
	if len(t.Collides) > 0 {
		field("collides", cyanStyle.Render(strings.Join(t.Collides, " ")))
	}
	var flags []string
	if t.Conflict {
		flags = append(flags, redStyle.Render("conflict"))
	}
	if t.Divergent {
		flags = append(flags, redStyle.Render("divergent"))
	}
	if t.Orphaned {
		flags = append(flags, redStyle.Render("orphaned: `jt reap`"))
	}
	if t.Empty {
		flags = append(flags, dimStyle.Render("no code yet"))
	}
	if t.Immutable {
		flags = append(flags, dimStyle.Render("immutable"))
	}
	if len(flags) > 0 {
		field("state", strings.Join(flags, "  "))
	}
	if d, n := core.Checklist(t.Msg.Detail); n > 0 {
		field("checklist", fmt.Sprintf("%d/%d", d, n))
	}
	field("updated", dimStyle.Render(t.Updated))
	if t.Msg.Detail != "" {
		out = append(out, "")
		for _, l := range strings.Split(t.Msg.Detail, "\n") {
			add(styleBodyLine(l))
		}
	}
	for _, tr := range t.Msg.Trailers {
		if !slices.Contains([]string{core.KeyStatus, core.KeyPriority, core.KeyScope}, tr.Key) {
			if len(out) > 0 && out[len(out)-1] != "" {
				out = append(out, "")
			}
			add(dimStyle.Render(tr.Key + ": " + tr.Value))
		}
	}
	return out
}

func styleBodyLine(l string) string {
	trim := strings.TrimSpace(l)
	switch {
	case strings.HasPrefix(trim, "- [x]"), strings.HasPrefix(trim, "- [X]"):
		return greenStyle.Render(l)
	case strings.HasPrefix(trim, "- [ ]"):
		return cyanStyle.Render(l)
	case strings.HasPrefix(l, "BLOCKED:"), strings.HasPrefix(l, "REOPENED"):
		return redStyle.Render(l)
	case strings.HasPrefix(l, "DECIDED"):
		return greenStyle.Render(l)
	case strings.HasPrefix(l, "TESTING:"):
		return statusStyle("testing").Render(l)
	case strings.HasPrefix(l, "DEFERRED:"):
		return dimStyle.Render(l)
	case strings.HasPrefix(l, "#"):
		return boldStyle.Render(l)
	}
	return l
}

func renderTrail(repo core.Repo, id string) []string {
	entries, err := repo.Evo(id)
	if err != nil {
		return []string{redStyle.Render(err.Error())}
	}
	var out []string
	for i := len(entries) - 1; i >= 0; i-- { // newest first: that's what you came for
		e := entries[i]
		head := dimStyle.Render(e.Time) + "  " + e.Commit
		if e.Empty {
			head += dimStyle.Render("  (empty)")
		}
		out = append(out, head)
		for _, l := range strings.Split(e.Text, "\n") {
			if e.First && l != "" {
				out = append(out, "    "+l)
			}
		}
		for _, ch := range e.Changes {
			switch {
			case strings.HasPrefix(ch, core.ChangeMeta):
				out = append(out, "    "+prioStyle.Render(strings.TrimPrefix(ch, core.ChangeMeta)))
			case strings.HasPrefix(ch, core.ChangeAdd):
				out = append(out, "    "+greenStyle.Render(ch))
			case strings.HasPrefix(ch, core.ChangeDel):
				out = append(out, "    "+redStyle.Render(ch))
			}
		}
		out = append(out, "")
	}
	return out
}

func renderDiff(repo core.Repo, id string) []string {
	s := repo.DiffStat(id)
	if s == "" || strings.HasPrefix(s, "0 files changed") {
		return []string{dimStyle.Render("no code changes")}
	}
	return strings.Split(s, "\n")
}

func (m *Model) viewGraph() string {
	h := max(m.h-2, 1)
	lines := []string{fit(titleStyle.Render("task graph"), m.w)}
	if m.graph == nil {
		lines = append(lines, dimStyle.Render(" loading…"))
	}
	for i := m.graphOff; i < len(m.graph) && len(lines) <= h; i++ {
		lines = append(lines, fit(m.graph[i], m.w))
	}
	for len(lines) <= h {
		lines = append(lines, "")
	}
	lines = append(lines, dimStyle.Render(" j/k scroll  g/G ends  esc back"))
	return strings.Join(lines, "\n")
}

func (m *Model) viewNew() string {
	f := &m.form
	label := func(i int, s string) string {
		if f.focused == i {
			return boldStyle.Render(fmt.Sprintf("%-9s", s))
		}
		return dimStyle.Render(fmt.Sprintf("%-9s", s))
	}
	var prios []string
	for i, p := range append(append([]string{}, core.Priorities...), "none") {
		if i == f.priority {
			prios = append(prios, selStyle.Render(" "+p+" "))
		} else {
			prios = append(prios, " "+p+" ")
		}
	}
	lines := []string{
		fit(titleStyle.Render("new task"), m.w), "",
		" " + label(fieldSummary, "summary") + f.summary.View(),
		" " + label(fieldPriority, "priority") + strings.Join(prios, ""),
		" " + label(fieldScope, "scope") + f.scope.View(),
		" " + label(fieldNeeds, "needs") + f.needs.View(),
	}
	if f.blockerHint != "" && f.focused == fieldNeeds {
		lines = append(lines, " "+dimStyle.Render("         selected task: "+f.blockerHint))
	}
	lines = append(lines, "", " "+label(fieldBody, "detail"))
	for _, l := range strings.Split(f.body.View(), "\n") {
		lines = append(lines, " "+l)
	}
	lines = append(lines, "", dimStyle.Render(" tab next field  ctrl+s file it  esc cancel"))
	if m.flash != "" && m.flashBad {
		lines = append(lines, redStyle.Render(" "+m.flash))
	}
	return strings.Join(lines, "\n")
}

func (m *Model) viewDecide() string {
	q := m.decideQueue()
	head := titleStyle.Render("decide") + " " + dimStyle.Render(fmt.Sprintf("%d open, %d decided", len(q), m.decidedCount))
	lines := []string{fit(head, m.w), ""}
	if !m.loaded {
		return strings.Join(append(lines, dimStyle.Render(" loading…")), "\n")
	}
	t, f := m.decideCurrent()
	w := max(min(m.w-4, 100), 20)
	wrap := func(s string) []string { return strings.Split(ansi.Wrap(s, w, ""), "\n") }
	if t == nil {
		msg := " Nothing waiting on you."
		if len(m.decideSkipped) > 0 {
			msg = fmt.Sprintf(" Nothing else: %d skipped, still blocked.", len(m.decideSkipped))
		}
		lines = append(lines, greenStyle.Render(msg), "", dimStyle.Render(" q back"))
		if m.flash != "" {
			lines = append(lines, "", dimStyle.Render(" "+m.flash))
		}
		return strings.Join(lines, "\n")
	}
	lines = append(lines, " "+idStyle.Render(t.ID)+" "+boldStyle.Render(t.Summary))
	if t.Scope != "" {
		lines = append(lines, " "+dimStyle.Render("scope "+t.Scope))
	}
	lines = append(lines, "")
	// The context above the question: it's what the worker found.
	before, _, _ := strings.Cut(t.Msg.Detail, "BLOCKED:")
	if ctx := strings.TrimSpace(before); ctx != "" {
		for _, l := range strings.Split(ctx, "\n") {
			for _, wl := range wrap(l) {
				lines = append(lines, " "+dimStyle.Render(wl))
			}
		}
		lines = append(lines, "")
	}
	for _, l := range wrap(f.Question) {
		lines = append(lines, " "+boldStyle.Render(l))
	}
	lines = append(lines, "")
	for i, o := range f.Options {
		label := fmt.Sprintf("%s) %s", o.Key, o.Text)
		if o.Recommended {
			label += "  (recommended)"
		}
		if i == min(m.decideIdx, len(f.Options)-1) && m.mode == modeDecide {
			lines = append(lines, " "+selStyle.Render(fit(" "+label, w)))
		} else if o.Recommended {
			lines = append(lines, " "+greenStyle.Render(" "+label))
		} else {
			lines = append(lines, "  "+label)
		}
	}
	switch m.mode {
	case modeDecideText:
		title := "Your decision"
		if m.decideMoot {
			title = "Why it's moot (marks the task done)"
		}
		lines = append(lines, "", " "+boldStyle.Render(title))
		for _, l := range strings.Split(m.decideText.View(), "\n") {
			lines = append(lines, " "+l)
		}
		lines = append(lines, "", dimStyle.Render(" ctrl+s record  esc back"))
	case modeInput:
		lines = append(lines, "", " "+boldStyle.Render(m.inputAsk)+m.input.View())
	default:
		hint := " enter choose  w write my own  m moot  s skip  d defer  q quit"
		if len(f.Options) == 0 {
			hint = " enter/w write answer  m moot  s skip  d defer  q quit"
		}
		lines = append(lines, "", dimStyle.Render(hint))
	}
	if m.flash != "" {
		st := dimStyle
		if m.flashBad {
			st = redStyle
		}
		lines = append(lines, "", st.Render(" "+m.flash))
	}
	return strings.Join(lines, "\n")
}

func (m *Model) viewHelp() string {
	return strings.Join([]string{
		fit(titleStyle.Render("jt keys"), m.w), "",
		boldStyle.Render(" Browse"),
		"   j/k ↑/↓   move               g/G      first / last",
		"   tab h/l   details/trail/diff J/K      scroll the pane",
		"   enter     pane full-screen   /        search",
		"   f 1-4     filter             v        task graph",
		"   O         open in jjui       r        refresh (also automatic)",
		"   y         copy id",
		"",
		boldStyle.Render(" Manage"),
		"   n         file a task        e        edit message in $EDITOR",
		"   s         set status         p        set priority",
		"   o         set scope          w        set what it waits on",
		"   S         start (claim)      d        done",
		"   b         block with question D       defer with reason",
		"   a / R     accept / reopen a testing task",
		"   B         decide queue       x        strip trailers",
		"   u         undo last jj op",
		"",
		dimStyle.Render(" any key to close"),
	}, "\n")
}
