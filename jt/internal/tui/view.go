package tui

import (
	"fmt"
	"slices"
	"strings"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/paginator"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"

	"jt/internal/core"
)

// ANSI palette only: this follows whatever theme the terminal has, which matters
// on a machine with a colorscheme switcher. Where jj has an opinion these are its
// colors (see `jj config list --include-defaults colors`, and assets/jjcolors.toml
// for the task statuses), so the board and `jj log` read as one tool.
var (
	dimColor   = lipgloss.BrightBlack
	greenColor = lipgloss.Green

	dimStyle    = lipgloss.NewStyle().Foreground(dimColor)
	boldStyle   = lipgloss.NewStyle().Bold(true)
	idStyle     = lipgloss.NewStyle().Foreground(lipgloss.Magenta).Bold(true)
	cyanStyle   = lipgloss.NewStyle().Foreground(lipgloss.Cyan)
	redStyle    = lipgloss.NewStyle().Foreground(lipgloss.Red)
	greenStyle  = lipgloss.NewStyle().Foreground(greenColor)
	yellowStyle = lipgloss.NewStyle().Foreground(lipgloss.Yellow)
	selStyle    = lipgloss.NewStyle().Reverse(true)
	metaStyle   = lipgloss.NewStyle().Foreground(lipgloss.Magenta)
	emptyStyle  = lipgloss.NewStyle().Foreground(lipgloss.Green)            // jj: empty
	addedStyle  = lipgloss.NewStyle().Foreground(lipgloss.Green)            // jj: diff added
	removeStyle = lipgloss.NewStyle().Foreground(lipgloss.Red)              // jj: diff removed
	commitStyle = lipgloss.NewStyle().Foreground(lipgloss.Blue)             // jj: commit_id
	timeStyle   = lipgloss.NewStyle().Foreground(lipgloss.Cyan)             // jj: timestamp
	wcIDStyle   = idStyle.Foreground(lipgloss.BrightMagenta)                // jj: working_copy change_id
	wcNodeStyle = lipgloss.NewStyle().Foreground(lipgloss.Green).Bold(true) // jj: node working_copy
	activeStyle = lipgloss.NewStyle().Bold(true).Underline(true)
	titleStyle  = lipgloss.NewStyle().Bold(true).Reverse(true).Padding(0, 1)
	filterOn    = lipgloss.NewStyle().Bold(true).Reverse(true).Foreground(lipgloss.Cyan).Padding(0, 1)
	filterOff   = dimStyle.Padding(0, 1)
	accentFrame = cyanStyle
)

var statusStyles = map[string]lipgloss.Style{
	"todo":          lipgloss.NewStyle().Foreground(lipgloss.Blue),
	"ready":         lipgloss.NewStyle().Foreground(lipgloss.BrightBlue),
	"doing":         lipgloss.NewStyle().Foreground(lipgloss.Yellow),
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

var laneStyles = map[string]lipgloss.Style{
	"In flight": lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Yellow),
	"Needs you": lipgloss.NewStyle().Bold(true).Foreground(lipgloss.BrightRed),
	"Ready":     lipgloss.NewStyle().Bold(true).Foreground(lipgloss.BrightBlue),
	"Waiting":   lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Blue),
	"Deferred":  lipgloss.NewStyle().Bold(true).Foreground(lipgloss.White),
	"Done":      dimStyle.Bold(true),
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

func prioStyle(p string) lipgloss.Style {
	switch p {
	case "P0":
		return lipgloss.NewStyle().Bold(true).Foreground(lipgloss.BrightRed)
	case "P1":
		return yellowStyle
	}
	return dimStyle // jj: task_priority. Only what's urgent earns a color.
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

// scrollInfo is what a frame's scrollbar needs. The zero value draws none.
type scrollInfo struct{ total, visible, offset int }

func scrollOf(v viewport.Model) scrollInfo {
	return scrollInfo{v.TotalLineCount(), v.Height(), v.YOffset()}
}

// frame draws a rounded box of exactly w×h cells, with a title let into the top
// edge, an optional label in the bottom edge, and a scrollbar on the right edge.
func frame(title, label string, body []string, w, h int, border lipgloss.Style, sc scrollInfo) []string {
	if w < 6 || h < 3 { // no room for a box: the content matters more
		out := make([]string, 0, h)
		for i := 0; i < h && i < len(body); i++ {
			out = append(out, fit(body[i], w))
		}
		return out
	}
	inner := h - 2
	title = ansi.Truncate(title, w-5, "…")
	top := border.Render("╭─ ") + title + border.Render(" "+strings.Repeat("─", max(w-5-lipgloss.Width(title), 0))+"╮")
	if title == "" {
		top = border.Render("╭" + strings.Repeat("─", w-2) + "╮")
	}
	thumbTop, thumbH := 0, 0
	if sc.total > sc.visible && inner > 0 {
		thumbH = max(inner*sc.visible/sc.total, 1)
		thumbTop = sc.offset * (inner - thumbH) / max(sc.total-sc.visible, 1)
	}
	out := make([]string, 0, h)
	out = append(out, top)
	for i := 0; i < inner; i++ {
		l := ""
		if i < len(body) {
			l = body[i]
		}
		right := border.Render("│")
		if i >= thumbTop && i < thumbTop+thumbH {
			right = cyanStyle.Render("┃")
		}
		out = append(out, border.Render("│")+fit(l, w-2)+right)
	}
	if lw := lipgloss.Width(label); label != "" && lw <= w-6 {
		out = append(out, border.Render("╰"+strings.Repeat("─", w-5-lw)+" ")+label+border.Render(" ─╯"))
	} else {
		out = append(out, border.Render("╰"+strings.Repeat("─", w-2)+"╯"))
	}
	return out
}

func pad(lines []string) []string {
	out := make([]string, len(lines))
	for i, l := range lines {
		out[i] = " " + l
	}
	return out
}

// modalWidth is an overlay's width: what it wants, if the terminal has it.
func modalWidth(termW, want int) int { return max(min(want, termW-2), 6) }

// pctLabel is a frame label saying how far through a viewport we are.
func pctLabel(v viewport.Model) string {
	if v.TotalLineCount() <= v.Height() {
		return ""
	}
	return dimStyle.Render(fmt.Sprintf("%3.0f%%", v.ScrollPercent()*100))
}

// clip holds a screen to the terminal, so nothing can scroll the frame off it.
func clip(s string, w, h int) string {
	lines := strings.Split(s, "\n")
	if len(lines) > h {
		lines = lines[:h]
	}
	for i, l := range lines {
		lines[i] = ansi.Truncate(l, w, "")
	}
	return strings.Join(lines, "\n")
}

// overlay centers a box over a dimmed copy of the screen behind it.
func overlay(base string, box []string, w, h int) string {
	lines := strings.Split(base, "\n")
	for i, l := range lines {
		lines[i] = dimStyle.Render(ansi.Strip(l))
	}
	content := strings.Join(box, "\n")
	x := max((w-lipgloss.Width(content))/2, 0)
	y := max((h-len(box))/2, 0)
	return lipgloss.NewCompositor(
		lipgloss.NewLayer(strings.Join(lines, "\n")),
		lipgloss.NewLayer(content).X(x).Y(y).Z(1),
	).Render()
}

func (m *Model) onDecide() bool {
	return m.mode == modeDecide || m.mode == modeDecideText || (m.mode == modeInput && m.inputAsk == decideDeferAsk)
}

// View draws the current mode.
func (m *Model) View() tea.View {
	var s string
	if m.w > 0 && m.h > 0 {
		s = clip(m.screen(), m.w, m.h)
		if box := m.modal(); box != nil {
			s = clip(overlay(s, box, m.w, m.h), m.w, m.h)
		}
	}
	v := tea.NewView(s)
	v.AltScreen = true
	return v
}

func (m *Model) screen() string {
	switch {
	case m.onDecide():
		return m.viewDecide()
	case m.mode == modeNew:
		return m.viewNew()
	case m.mode == modeGraph:
		return m.viewGraph()
	}
	return m.viewBoard()
}

// modal is the box floating over the screen, if the mode has one.
func (m *Model) modal() []string {
	switch m.mode {
	case modePicker:
		w := modalWidth(m.w, 44)
		body := pad(strings.Split(m.picker.View(), "\n"))
		body = append(body, "", " "+m.help.ShortHelpView([]key.Binding{keys.Enter, keys.Esc}))
		return frame(boldStyle.Render(m.pickAsk), "", body, w, len(body)+2, accentFrame, scrollInfo{})
	case modeConfirm:
		w := modalWidth(m.w, 60)
		body := pad(strings.Split(ansi.Wrap(boldStyle.Render(m.askText), max(w-4, 1), ""), "\n"))
		body = append(body, "", " "+m.help.ShortHelpView([]key.Binding{hint("y", "confirm"), hint("n", "cancel")}))
		return frame(boldStyle.Render("Confirm"), "", body, w, len(body)+2, accentFrame, scrollInfo{})
	case modeInput:
		w := modalWidth(m.w, 70)
		title := strings.TrimRight(m.inputAsk, ": ?")
		body := []string{" " + m.input.View(), "", " " + m.help.ShortHelpView([]key.Binding{hint("enter", "ok"), hint("esc", "cancel")})}
		return frame(boldStyle.Render(title), "", body, w, len(body)+2, accentFrame, scrollInfo{})
	case modeHelp:
		cols := make([]string, 0, 4)
		for _, group := range keys.fullHelp() {
			cols = append(cols, m.help.FullHelpView([][]key.Binding{group}))
		}
		var content string
		if m.w >= 100 {
			content = lipgloss.JoinHorizontal(lipgloss.Top, cols[0], "    ", cols[1], "    ", cols[2], "    ", cols[3])
		} else { // two columns of two: nothing gets truncated away on a narrow terminal
			content = lipgloss.JoinVertical(lipgloss.Left,
				lipgloss.JoinHorizontal(lipgloss.Top, cols[0], "    ", cols[1]), "",
				lipgloss.JoinHorizontal(lipgloss.Top, cols[2], "    ", cols[3]))
		}
		body := pad(strings.Split(content, "\n"))
		body = append(body, "", " "+dimStyle.Render("any key to close"))
		return frame(boldStyle.Render("jt keys"), "", body, modalWidth(m.w, lipgloss.Width(content)+4), len(body)+2, accentFrame, scrollInfo{})
	}
	return nil
}

func (m *Model) viewBoard() string {
	bodyH := max(m.h-3, 0)
	lw, dw := m.boardWidths()
	var body []string
	switch {
	case !m.loaded:
		body = frame(boldStyle.Render("Tasks"), "", []string{" " + m.spinner.View() + dimStyle.Render(" loading…")}, m.w, bodyH, dimStyle, scrollInfo{})
	case dw == 0:
		body = m.listPane(m.w, bodyH)
	case lw == 0:
		body = m.detailPane(m.w, bodyH)
	default:
		left, right := m.listPane(lw, bodyH), m.detailPane(dw, bodyH)
		for i := 0; i < bodyH && i < len(left) && i < len(right); i++ {
			body = append(body, left[i]+right[i])
		}
	}
	lines := append([]string{fit(m.header(), m.w), fit(m.filterBar(), m.w)}, body...)
	for len(lines) < m.h-1 {
		lines = append(lines, "")
	}
	lines = append(lines, fit(m.footer(), m.w))
	return strings.Join(lines, "\n")
}

func (m *Model) header() string {
	var chips []string
	right := ""
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
		if n := len(m.board.Tasks); n > 0 {
			right = m.bar.ViewAs(float64(counts["done"])/float64(n)) + dimStyle.Render(fmt.Sprintf(" %d/%d done", counts["done"], n))
		}
	}
	if m.busy {
		right = m.spinner.View() + dimStyle.Render(" working…  ") + right
	}
	left := titleStyle.Render("jt "+m.repoName) + " " + strings.Join(chips, "  ")
	gap := m.w - lipgloss.Width(left) - lipgloss.Width(right) - 1
	if gap < 1 { // chips are what you came for; the bar can go
		if m.busy {
			return left + " " + m.spinner.View()
		}
		return left
	}
	return left + strings.Repeat(" ", gap) + right + " "
}

func (m *Model) filterBar() string {
	var parts []string
	for i, f := range filters {
		label := fmt.Sprintf("%d %s", i+1, f.name)
		if m.board != nil {
			n := 0
			for _, t := range m.board.Tasks {
				if f.keep(t) {
					n++
				}
			}
			label += fmt.Sprintf(" %d", n)
		}
		if i == m.filter {
			parts = append(parts, filterOn.Render(label))
		} else {
			parts = append(parts, filterOff.Render(label))
		}
	}
	line := strings.Join(parts, " ")
	if m.mode == modeSearch {
		line += "   " + m.searchBox.View()
	} else if m.search != "" {
		line += "   " + cyanStyle.Render("/"+m.search)
	}
	return line
}

// flashLine is the outcome of the last action, if there's one to show.
func (m *Model) flashLine() string {
	switch {
	case m.flash == "":
		return ""
	case m.flashBad:
		return redStyle.Render(" ✖ " + m.flash)
	}
	return greenStyle.Render(" ✓ " + m.flash)
}

func (m *Model) footer() string {
	if f := m.flashLine(); f != "" {
		return f
	}
	t := m.current()
	return " " + m.help.ShortHelpView(keys.shortHelp(t != nil && t.Status == "testing"))
}

func (m *Model) listPane(w, h int) []string {
	title := boldStyle.Render("Tree")
	if m.lanes {
		title = boldStyle.Render("Lanes")
	}
	var body []string
	if len(m.list.Items()) == 0 {
		msg := "nothing here"
		if m.board != nil && len(m.board.Tasks) == 0 {
			msg = "no tasks yet: press n to file one"
		}
		body = []string{dimStyle.Render(" " + msg)}
	} else {
		body = strings.Split(m.list.View(), "\n")
		// A page can start mid-lane, so the title says which lane you're in.
		if lane := m.currentLane(); lane != "" {
			title += dimStyle.Render(" › ") + laneStyle(lane).Render(lane)
		}
	}
	return frame(title, m.listLabel(w), body, w, h, dimStyle, scrollInfo{})
}

// listLabel is the overview in the list's bottom edge: what's showing, how much of
// it has any code, and the pager when there's more than a page.
func (m *Model) listLabel(w int) string {
	shown, empty, added, removed := 0, 0, 0, 0
	for _, it := range m.list.Items() {
		if t := it.(row).task; t != nil {
			shown++
			added += t.Added
			removed += t.Removed
			if t.Empty {
				empty++
			}
		}
	}
	pager := ""
	if p := m.list.Paginator; p.TotalPages > 1 {
		if p.TotalPages > 12 {
			p.Type = paginator.Arabic
		}
		pager = p.View()
	}
	if shown == 0 {
		return pager
	}
	stats := dimStyle.Render(fmt.Sprintf("%d tasks", shown))
	if empty > 0 {
		stats += dimStyle.Render(" · ") + emptyStyle.Render(fmt.Sprintf("%d empty", empty))
	}
	if added+removed > 0 {
		stats += dimStyle.Render(" · ") + countStyle(added, addedStyle).Render(fmt.Sprintf("+%d", added)) + " " + countStyle(removed, removeStyle).Render(fmt.Sprintf("-%d", removed))
	}
	if pager == "" {
		return stats
	}
	if both := stats + dimStyle.Render(" · ") + pager; lipgloss.Width(both) <= w-6 {
		return both
	}
	return pager
}

// countStyle colors a diff count, unless there's nothing to count.
func countStyle(n int, st lipgloss.Style) lipgloss.Style {
	if n == 0 {
		return dimStyle
	}
	return st
}

// codeStat says whether a task has any code, and how much. It's plain and styled
// because a selected row is reversed as a whole.
func codeStat(t *core.Task, compact bool) (plain, styled string) {
	switch {
	case t.Empty && compact:
		return "∅", emptyStyle.Render("∅")
	case t.Empty:
		return "(empty)", emptyStyle.Render("(empty)")
	case t.Added+t.Removed > 0:
		a, r := fmt.Sprintf("+%d", t.Added), fmt.Sprintf("-%d", t.Removed)
		return a + " " + r, countStyle(t.Added, addedStyle).Render(a) + " " + countStyle(t.Removed, removeStyle).Render(r)
	case t.Files > 0: // binary or mode changes: code, but no lines
		s := fmt.Sprintf("%d file", t.Files)
		if t.Files > 1 {
			s += "s"
		}
		return s, dimStyle.Render(s)
	}
	return "", ""
}

func laneStyle(name string) lipgloss.Style {
	if st, ok := laneStyles[name]; ok {
		return st
	}
	return boldStyle
}

// currentLane is the header above the selected row.
func (m *Model) currentLane() string {
	items := m.list.Items()
	for i := min(m.list.Index(), len(items)-1); i >= 0; i-- {
		if r := items[i].(row); r.task == nil {
			return r.header
		}
	}
	return ""
}

// rowLine draws one row of the board.
func rowLine(r row, selected bool, w int) string {
	if r.task == nil {
		head := " " + laneStyle(r.header).Render(r.header) + dimStyle.Render(fmt.Sprintf(" %d ", r.count))
		return head + dimStyle.Render(strings.Repeat("─", max(w-lipgloss.Width(head)-1, 0)))
	}
	t := r.task
	prio := fmt.Sprintf("%-2s", t.Priority)
	mark := ""
	switch {
	case t.Conflict:
		mark = "!conflict"
	case t.Orphaned:
		mark = "!orphaned"
	case t.Status == "doing" && len(t.Workspaces) > 0:
		mark = "@" + strings.Join(t.Workspaces, ",")
	case t.Needs != "":
		mark = fmt.Sprintf("⇢%d", len(t.NeedsList()))
	case len(t.Collides) > 0:
		mark = "⚠scope"
	}
	if t.Current && !strings.HasPrefix(mark, "@") {
		mark = strings.TrimSpace("@ " + mark)
	}
	stat, statStyled := codeStat(t, w < 60)
	right, rightStyled := mark, cyanStyle.Render(mark)
	switch {
	case t.Conflict || t.Orphaned:
		rightStyled = redStyle.Render(mark)
	case mark == "@":
		rightStyled = wcNodeStyle.Render(mark)
	}
	if stat != "" {
		if right != "" {
			right, rightStyled = right+"  ", rightStyled+"  "
		}
		right, rightStyled = right+stat, rightStyled+statStyled
	}
	// " tree g id pp summary…  mark stat "
	used := 1 + lipgloss.Width(r.prefix) + 2 + lipgloss.Width(t.ID) + 1 + lipgloss.Width(prio) + 1
	rightW := lipgloss.Width(right)
	if rightW > 0 {
		rightW += 2
	}
	summary := ansi.Truncate(t.Summary, max(w-used-rightW-1, 4), "…")
	gap := strings.Repeat(" ", max(w-used-lipgloss.Width(summary)-rightW-1, 0))
	sep := ""
	if right != "" {
		sep = "  "
	}
	if selected {
		return selStyle.Render(fit(" "+r.prefix+glyph(t.Status)+" "+t.ID+" "+prio+" "+summary+gap+sep+right, w))
	}
	if t.Status == "done" || t.Status == "deferred" {
		summary = dimStyle.Render(summary)
	}
	id := renderID(t.ID)
	if t.Current {
		id = renderWorkingCopyID(t.ID)
	}
	return " " + dimStyle.Render(r.prefix) + statusStyle(t.Status).Render(glyph(t.Status)) + " " + id + " " + prioStyle(t.Priority).Render(prio) + " " + summary + gap + sep + rightStyled
}

// pickLine draws one option of the picker.
func pickLine(o string, selected bool, w int) string {
	label := "  " + o
	if _, known := statusGlyphs[o]; known {
		label = " " + glyph(o) + " " + o
	}
	if selected {
		return selStyle.Render(fit(label, w))
	}
	if _, known := statusGlyphs[o]; known {
		return " " + statusStyle(o).Render(glyph(o)) + " " + o
	}
	return "  " + prioStyle(o).Render(o)
}

func (m *Model) detailPane(w, h int) []string {
	if m.current() == nil {
		return frame(boldStyle.Render("Details"), "", nil, w, h, dimStyle, scrollInfo{})
	}
	var parts []string
	for i, name := range tabs {
		if i == m.tab {
			parts = append(parts, activeStyle.Render(name))
		} else {
			parts = append(parts, dimStyle.Render(name))
		}
	}
	title := strings.Join(parts, dimStyle.Render(" · "))
	body := pad(strings.Split(m.detail.View(), "\n"))
	return frame(title, pctLabel(m.detail), body, w, h, dimStyle, scrollOf(m.detail))
}

// detailContent is what the current tab shows, wrapped to the pane.
func (m *Model) detailContent(w int) []string {
	t := m.current()
	if t == nil {
		return nil
	}
	if m.tab == 0 {
		return m.detailLines(t, w)
	}
	var lines []string
	for _, l := range m.cache[detailKey(m.tab, t)] {
		lines = append(lines, strings.Split(ansi.Wrap(l, w, ""), "\n")...)
	}
	return lines
}

func (m *Model) detailLines(t *core.Task, w int) []string {
	var out []string
	add := func(s string) { out = append(out, strings.Split(ansi.Wrap(s, w, ""), "\n")...) }
	field := func(k, v string) { add(dimStyle.Render(fmt.Sprintf("%-10s", k)) + v) }

	add(boldStyle.Render(t.Summary))
	out = append(out, "")
	status := statusStyle(t.Status).Render(glyph(t.Status) + " " + t.Status)
	if t.Priority != "" {
		status += "  " + prioStyle(t.Priority).Render(t.Priority)
	}
	if t.Ready {
		status += "  " + greenStyle.Render("ready")
	}
	field("status", status)
	id := renderID(t.ID)
	if t.Current {
		id = renderWorkingCopyID(t.ID) + " " + wcNodeStyle.Render("@")
	}
	field("id", id+" "+commitStyle.Render(t.CommitID))
	if _, stat := codeStat(t, false); stat != "" {
		if t.Files > 0 && t.Added+t.Removed > 0 {
			stat += dimStyle.Render(fmt.Sprintf("  %d files", t.Files))
		}
		if t.Empty {
			stat += dimStyle.Render("  no code yet")
		}
		field("code", stat)
	}
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
			field("needs", renderID(id)+" "+summary)
		}
	}
	if m.board != nil {
		for _, d := range m.board.Dependents(t.ID) {
			field("blocks", renderID(d.ID)+" "+d.Summary)
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
	if t.Immutable {
		flags = append(flags, dimStyle.Render("immutable"))
	}
	if len(flags) > 0 {
		field("state", strings.Join(flags, "  "))
	}
	if d, n := core.Checklist(t.Msg.Detail); n > 0 {
		field("checklist", m.bar.ViewAs(float64(d)/float64(n))+fmt.Sprintf(" %d/%d", d, n))
	}
	field("updated", timeStyle.Render(t.Updated))
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
		head := timeStyle.Render(e.Time) + "  " + commitStyle.Render(e.Commit)
		if e.Empty {
			head += "  " + emptyStyle.Render("(empty)")
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
				out = append(out, "    "+metaStyle.Render(strings.TrimPrefix(ch, core.ChangeMeta)))
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
		return []string{emptyStyle.Render("(empty)") + dimStyle.Render(" no code changes")}
	}
	lines := strings.Split(s, "\n")
	longest := 0
	for _, l := range lines {
		if _, _, bar, ok := splitStatLine(l); ok {
			longest = max(longest, len(bar))
		}
	}
	for i, l := range lines {
		lines[i] = styleStatLine(l, longest)
	}
	return lines
}

// statBarWidth is the most a stat bar gets. jj sizes its bars for a whole terminal,
// which wraps in a pane.
const statBarWidth = 24

// splitStatLine takes a file line of `--stat` apart: "path | 12 ", and its bar.
func splitStatLine(l string) (head, count, bar string, ok bool) {
	i := strings.LastIndex(l, " | ")
	if i < 0 {
		return "", "", "", false
	}
	head, tail := l[:i+3], l[i+3:]
	j := strings.IndexAny(tail, "+-")
	if j < 0 {
		return head, tail, "", true
	}
	return head, tail[:j], tail[j:], true
}

// styleStatLine colors a `--stat` line the way jj colors a diff, scaling its bar
// so the longest of them fits statBarWidth.
func styleStatLine(l string, longest int) string {
	head, count, bar, ok := splitStatLine(l)
	if !ok { // the totals line
		parts := strings.Split(l, ", ")
		for j, p := range parts {
			switch {
			case strings.HasPrefix(p, "0 "):
				parts[j] = dimStyle.Render(p)
			case strings.Contains(p, "insertion"):
				parts[j] = addedStyle.Render(p)
			case strings.Contains(p, "deletion"):
				parts[j] = removeStyle.Render(p)
			default:
				parts[j] = boldStyle.Render(p)
			}
		}
		return strings.Join(parts, dimStyle.Render(", "))
	}
	plus, minus := strings.Count(bar, "+"), strings.Count(bar, "-")
	if longest > statBarWidth {
		scale := func(n int) int {
			if n == 0 {
				return 0
			}
			return max(n*statBarWidth/longest, 1) // a change never rounds away
		}
		plus, minus = scale(plus), scale(minus)
	}
	return head + count + addedStyle.Render(strings.Repeat("+", plus)) + removeStyle.Render(strings.Repeat("-", minus))
}

func (m *Model) viewGraph() string {
	var body []string
	if m.graphLoading {
		body = []string{" " + m.spinner.View() + dimStyle.Render(" loading…")}
	} else {
		body = pad(strings.Split(m.graphView.View(), "\n"))
	}
	lines := frame(boldStyle.Render("Task graph"), pctLabel(m.graphView), body, m.w, max(m.h-1, 0), dimStyle, scrollOf(m.graphView))
	lines = append(lines, " "+m.help.ShortHelpView([]key.Binding{
		keys.Up, hint("g/G", "ends"), keys.PageDown, keys.Left, hint("esc", "back"),
	}))
	return strings.Join(lines, "\n")
}

func (m *Model) viewNew() string {
	f := &m.form
	label := func(i int, s string) string {
		st := dimStyle
		if f.focused == i {
			st = cyanStyle.Bold(true)
		}
		return st.Render(fmt.Sprintf("%-9s", s))
	}
	var prios []string
	for i, p := range append(append([]string{}, core.Priorities...), "none") {
		switch {
		case i == f.priority && f.focused == fieldPriority:
			prios = append(prios, selStyle.Render(" "+p+" "))
		case i == f.priority:
			prios = append(prios, boldStyle.Underline(true).Render(" "+p+" "))
		default:
			prios = append(prios, dimStyle.Render(" "+p+" "))
		}
	}
	body := []string{
		" " + label(fieldSummary, "summary") + f.summary.View() + " " + f.counter(),
		" " + label(fieldPriority, "priority") + "  " + strings.Join(prios, ""),
		" " + label(fieldScope, "scope") + f.scope.View(),
		" " + label(fieldNeeds, "needs") + f.needs.View(),
	}
	if f.blockerHint != "" && f.focused == fieldNeeds {
		body = append(body, " "+dimStyle.Render("           selected task: "+f.blockerHint))
	} else {
		body = append(body, "")
	}
	body = append(body, " "+label(fieldBody, "detail"))
	body = append(body, pad(strings.Split(f.body.View(), "\n"))...)
	lines := frame(boldStyle.Render("New task"), "", body, m.w, max(m.h-1, 0), accentFrame, scrollInfo{})
	foot := m.flashLine()
	if foot == "" {
		foot = " " + m.help.ShortHelpView([]key.Binding{hint("tab", "next field"), hint("ctrl+s", "file it"), hint("esc", "cancel")})
	}
	return strings.Join(append(lines, foot), "\n")
}

// decideWidth is the measure for the decide screen's text.
func (m *Model) decideWidth() int { return max(min(m.w-4, 100), 20) }

// decideContext is what the worker found: the detail above the question.
func decideContext(t *core.Task, w int) []string {
	before, _, _ := strings.Cut(t.Msg.Detail, "BLOCKED:")
	ctx := strings.TrimSpace(before)
	if ctx == "" {
		return nil
	}
	var out []string
	for _, l := range strings.Split(ctx, "\n") {
		for _, wl := range strings.Split(ansi.Wrap(l, w, ""), "\n") {
			out = append(out, dimStyle.Render(wl))
		}
	}
	return out
}

// decideBottom is the part of the decide screen that always stays in view: the
// question, its options, and whatever is being typed.
func (m *Model) decideBottom(f *core.Fork, w int) []string {
	var lines []string
	for _, l := range strings.Split(ansi.Wrap(f.Question, w, ""), "\n") {
		lines = append(lines, boldStyle.Render(l))
	}
	lines = append(lines, "")
	for i, o := range f.Options {
		label := fmt.Sprintf("%s) %s", o.Key, o.Text)
		if o.Recommended {
			label += "  ★ recommended"
		}
		switch {
		case i == min(m.decideIdx, len(f.Options)-1) && m.mode == modeDecide:
			lines = append(lines, selStyle.Render(fit("▸ "+label, w)))
		case o.Recommended:
			lines = append(lines, "  "+greenStyle.Render(label))
		default:
			lines = append(lines, "  "+label)
		}
	}
	if m.mode == modeDecideText {
		title := "Your decision"
		if m.decideMoot {
			title = "Why it's moot (marks the task done)"
		}
		lines = append(lines, "", cyanStyle.Bold(true).Render(title))
		lines = append(lines, strings.Split(m.decideText.View(), "\n")...)
	}
	return lines
}

// syncDecide fits the context viewport into whatever the question leaves over.
func (m *Model) syncDecide() {
	if !m.onDecide() || !m.loaded {
		return
	}
	t, f := m.decideCurrent()
	if t == nil {
		return
	}
	w := m.decideWidth()
	ctx := decideContext(t, w)
	room := max(m.h-4, 0) - len(m.decideBottom(f, w)) - 1 // frame, head, footer; one blank
	m.decideView.SetWidth(w)
	m.decideView.SetHeight(max(min(len(ctx), room), 0))
	m.decideView.SetContentLines(ctx)
	if t.ID != m.decideShown {
		m.decideShown = t.ID
		m.decideView.GotoTop()
	}
}

func (m *Model) viewDecide() string {
	q := m.decideQueue()
	head := titleStyle.Render("decide") + " " + dimStyle.Render(fmt.Sprintf("%d open, %d decided", len(q), m.decidedCount))
	if total := len(q) + m.decidedCount; total > 0 && m.w >= 60 {
		head += "  " + m.bar.ViewAs(float64(m.decidedCount)/float64(total))
	}
	if m.busy {
		head += "  " + m.spinner.View()
	}
	frameH := max(m.h-2, 0)
	foot := m.flashLine()
	if !m.loaded {
		lines := append([]string{fit(head, m.w)}, frame("", "", []string{" " + m.spinner.View() + dimStyle.Render(" loading…")}, m.w, frameH, dimStyle, scrollInfo{})...)
		return strings.Join(lines, "\n")
	}
	t, f := m.decideCurrent()
	if t == nil {
		msg := " Nothing waiting on you."
		if len(m.decideSkipped) > 0 {
			msg = fmt.Sprintf(" Nothing else: %d skipped, still blocked.", len(m.decideSkipped))
		}
		lines := append([]string{fit(head, m.w)}, frame("", "", []string{greenStyle.Render(msg)}, m.w, frameH, greenStyle, scrollInfo{})...)
		if foot == "" {
			foot = " " + m.help.ShortHelpView([]key.Binding{hint("q", "back")})
		}
		return strings.Join(append(lines, foot), "\n")
	}
	w := m.decideWidth()
	var body []string
	if t.Scope != "" {
		body = append(body, " "+dimStyle.Render("scope "+t.Scope))
	}
	if m.decideView.Height() > 0 {
		body = append(body, pad(strings.Split(m.decideView.View(), "\n"))...)
	}
	if len(body) > 0 {
		body = append(body, "")
	}
	body = append(body, pad(m.decideBottom(f, w))...)
	title := renderID(t.ID) + " " + boldStyle.Render(t.Summary)
	lines := append([]string{fit(head, m.w)}, frame(title, pctLabel(m.decideView), body, m.w, frameH, accentFrame, scrollOf(m.decideView))...)
	if foot == "" {
		foot = " " + m.help.ShortHelpView(m.decideHelp(f))
	}
	return strings.Join(append(lines, foot), "\n")
}

func (m *Model) decideHelp(f *core.Fork) []key.Binding {
	switch {
	case m.mode == modeDecideText:
		return []key.Binding{hint("ctrl+s", "record"), hint("esc", "back")}
	case len(f.Options) == 0:
		return []key.Binding{hint("enter/w", "write answer"), hint("m", "moot"), hint("s", "skip"), hint("d", "defer"), keys.ScrollDown, hint("q", "quit")}
	}
	return []key.Binding{hint("enter", "choose"), hint("w", "write my own"), hint("m", "moot"), hint("s", "skip"), hint("d", "defer"), keys.ScrollDown, hint("q", "quit")}
}

// renderID colors a short change id like jj: bold prefix, dim rest.
func renderID(id string) string {
	p, r := core.SplitID(id)
	return idStyle.Render(p) + dimStyle.Render(r)
}

// renderWorkingCopyID is renderID for this workspace's @, which jj brightens.
func renderWorkingCopyID(id string) string {
	p, r := core.SplitID(id)
	return wcIDStyle.Render(p) + dimStyle.Render(r)
}
