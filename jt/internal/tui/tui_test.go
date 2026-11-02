package tui

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"jt/internal/core"
)

func scratch(t *testing.T) core.Repo {
	t.Helper()
	if _, err := exec.LookPath("jj"); err != nil {
		t.Skip("jj not installed")
	}
	dir := t.TempDir()
	cfg := filepath.Join(dir, "jj.toml")
	os.WriteFile(cfg, []byte("[user]\nname='t'\nemail='t@t'\n"), 0o644)
	t.Setenv("JJ_CONFIG", cfg)
	cmd := exec.Command("jj", "git", "init", "--quiet", dir+"/r")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatal(string(out))
	}
	return core.Repo{Dir: dir + "/r"}
}

func keyMsg(s string) tea.KeyPressMsg {
	switch s {
	case "enter":
		return tea.KeyPressMsg{Code: tea.KeyEnter}
	case "esc":
		return tea.KeyPressMsg{Code: tea.KeyEscape}
	case "tab":
		return tea.KeyPressMsg{Code: tea.KeyTab}
	}
	r := []rune(s)[0]
	return tea.KeyPressMsg{Code: r, Text: s}
}

// drive runs a command and any message it yields, synchronously: enough to get
// mutations and reloads applied, without timers.
func drive(t *testing.T, m *Model, cmd tea.Cmd) {
	t.Helper()
	if cmd == nil {
		return
	}
	// Only jt's own messages are followed: widget commands like cursor blink
	// re-arm forever, and timers aren't what these tests are about.
	done := make(chan tea.Msg, 1)
	go func() { done <- cmd() }()
	var msg tea.Msg
	select {
	case msg = <-done:
	case <-time.After(5 * time.Second):
		return
	}
	switch msg.(type) {
	case boardMsg, actionMsg, linesMsg, graphMsg:
		_, next := m.Update(msg)
		drive(t, m, next)
	case tea.BatchMsg:
		for _, c := range msg.(tea.BatchMsg) {
			drive(t, m, c)
		}
	}
}

func press(t *testing.T, m *Model, keys ...string) {
	t.Helper()
	for _, k := range keys {
		_, cmd := m.Update(keyMsg(k))
		drive(t, m, cmd)
	}
}

func load(t *testing.T, m *Model) {
	t.Helper()
	drive(t, m, m.loadCmd())
}

// Every mode must draw at any size, including before the first WindowSizeMsg and
// in absurdly small terminals. (A size message once hit an uninitialised form and
// panicked on launch.)
func TestEveryModeDrawsAtAnySize(t *testing.T) {
	r := scratch(t)
	r.New(core.NewOpts{Summary: "a task with a rather long summary line to wrap", Body: "body\n\n- [x] one\n- [ ] two", Scope: "src", Priority: "P1"})
	res, _ := r.New(core.NewOpts{Summary: "blocked one"})
	r.Block(res.Task.ID, "which?", []string{"this", "that"}, 1)

	sizes := [][2]int{{0, 0}, {1, 1}, {10, 3}, {40, 10}, {80, 24}, {89, 20}, {90, 20}, {200, 60}}
	modes := []mode{modeNormal, modeSearch, modePicker, modeInput, modeConfirm, modeNew, modeHelp, modeGraph, modeDecide, modeDecideText}
	for _, screen := range []Screen{ScreenBoard, ScreenDecide} {
		for _, sz := range sizes {
			m := newModel(r, screen, "builtin_log_compact")
			_ = m.View() // before anything arrives
			m.Update(tea.WindowSizeMsg{Width: sz[0], Height: sz[1]})
			load(t, m)
			m.pick("x", core.Statuses, "", nil)
			for _, md := range modes {
				m.mode = md
				m.sync()
				content := m.View().Content
				if got := lipgloss.Height(content); content != "" && got > sz[1] {
					t.Errorf("mode %d at %v: %d lines", md, sz, got)
				}
				for _, l := range strings.Split(content, "\n") {
					if got := lipgloss.Width(l); got > sz[0] {
						t.Errorf("mode %d at %v: line is %d wide: %q", md, sz, got, l)
					}
				}
			}
		}
	}
}

// The list pages, so its rows outnumbering the terminal is the case to get right:
// j must walk every task in order, across pages and over the lane headers.
func TestListWalksAcrossPagesAndHeaders(t *testing.T) {
	r := scratch(t)
	var want []string
	for _, p := range []string{"P0", "P1", "P2", "P3"} {
		for i := range 3 {
			res, err := r.New(core.NewOpts{Summary: fmt.Sprintf("%s number %d", p, i), Priority: p})
			if err != nil {
				t.Fatal(err)
			}
			want = append(want, res.Task.ID)
		}
	}
	r.Block(want[0], "which?", nil, 0) // a second lane, so there's a header to step over
	m := newModel(r, ScreenBoard, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 10})
	load(t, m)
	press(t, m, "t") // lanes: the view with headers to step over
	if m.list.Paginator.TotalPages < 2 {
		t.Fatalf("expected several pages, got %d", m.list.Paginator.TotalPages)
	}
	seen := map[string]bool{m.current().ID: true}
	for range len(want) - 1 {
		press(t, m, "j")
		c := m.current()
		if c == nil {
			t.Fatal("cursor landed on a lane header")
		}
		seen[c.ID] = true
		if !strings.Contains(m.View().Content, c.Summary) {
			t.Errorf("selected task %q isn't on screen", c.Summary)
		}
	}
	if len(seen) != len(want) {
		t.Errorf("walked %d of %d tasks", len(seen), len(want))
	}
	press(t, m, "g")
	if c := m.current(); c == nil {
		t.Error("g landed on a header")
	}
	press(t, m, "G")
	if c := m.current(); c == nil {
		t.Error("G landed on a header")
	}
}

func TestTreeShowsDependencies(t *testing.T) {
	r := scratch(t)
	base, _ := r.New(core.NewOpts{Summary: "base", Priority: "P0"})
	r.New(core.NewOpts{Summary: "left", Priority: "P1", Blockers: []string{base.Task.ID}})
	right, _ := r.New(core.NewOpts{Summary: "right", Priority: "P2", Blockers: []string{base.Task.ID}})
	r.New(core.NewOpts{Summary: "on top", Priority: "P2", Blockers: []string{right.Task.ID}})
	m := newModel(r, ScreenBoard, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	load(t, m)
	prefix := map[string]string{}
	for _, it := range m.list.Items() {
		rw := it.(row)
		if rw.task == nil {
			t.Fatalf("tree has a header: %q", rw.header)
		}
		prefix[rw.task.Summary] = rw.prefix
	}
	want := map[string]string{"base": "", "left": "├ ", "right": "└ ", "on top": "  ↳ "}
	for s, p := range want {
		if prefix[s] != p {
			t.Errorf("%q: prefix %q, want %q (all: %q)", s, prefix[s], p, prefix)
		}
	}
	content := m.View().Content
	if !strings.Contains(content, "(empty)") {
		t.Errorf("empty tasks aren't marked: %q", content)
	}
	// A filtered-out parent hands its children to the nearest visible ancestor.
	r.Set(right.Task.ID, [][2]string{{"status", "done"}})
	load(t, m)
	for _, it := range m.list.Items() {
		if rw := it.(row); rw.task.Summary == "on top" && rw.prefix != "└ " && rw.prefix != "├ " {
			t.Errorf("hoisted child prefix %q", rw.prefix)
		}
	}
}

func TestDetailScrollsAndResetsOnMove(t *testing.T) {
	r := scratch(t)
	r.New(core.NewOpts{Summary: "long", Body: strings.Repeat("line\n\n", 40), Priority: "P0"})
	r.New(core.NewOpts{Summary: "next", Priority: "P1"})
	m := newModel(r, ScreenBoard, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 20})
	load(t, m)
	press(t, m, "J")
	if m.detail.YOffset() == 0 {
		t.Fatal("J didn't scroll the detail pane")
	}
	press(t, m, "j", "k")
	if m.detail.YOffset() != 0 {
		t.Errorf("selection change kept the offset: %d", m.detail.YOffset())
	}
}

// The form can't take more than the limit in the first place.
func TestFormHoldsSummaryToLimit(t *testing.T) {
	r := scratch(t)
	m := newModel(r, ScreenBoard, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	load(t, m)
	press(t, m, "n")
	for range core.MaxSummary + 5 {
		press(t, m, "x")
	}
	if n := len(m.form.summary.Value()); n != core.MaxSummary {
		t.Errorf("summary holds %d characters", n)
	}
	if !strings.Contains(m.View().Content, fmt.Sprintf("%d/%d", core.MaxSummary, core.MaxSummary)) {
		t.Error("counter not shown")
	}
}

func TestBoardFlow(t *testing.T) {
	r := scratch(t)
	x, _ := r.New(core.NewOpts{Summary: "first", Priority: "P1"})
	y, _ := r.New(core.NewOpts{Summary: "second", Priority: "P2"})
	m := newModel(r, ScreenBoard, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	load(t, m)
	if m.current() == nil || m.current().ID != x.Task.ID {
		t.Fatalf("selection starts on %+v", m.current())
	}
	press(t, m, "j")
	if m.current().ID != y.Task.ID {
		t.Fatalf("j moved to %+v", m.current())
	}

	// Status through the picker: "doing" is two below "todo".
	press(t, m, "s", "j", "j", "enter")
	b, _ := r.Load()
	if b.ByID[y.Task.ID].Status != "doing" {
		t.Errorf("status %s", b.ByID[y.Task.ID].Status)
	}
	if m.selected != y.Task.ID {
		t.Errorf("selection lost: %s", m.selected)
	}

	// A gate refused by core shows up as a flash, not a crash or silence.
	press(t, m, "b", "enter") // block with no question
	press(t, m, "S")
	if !m.flashBad || !strings.Contains(m.flash, "blocked") {
		t.Errorf("flash %q", m.flash)
	}

	// Filing through the form.
	press(t, m, "n")
	for _, c := range "third" {
		press(t, m, string(c))
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: 's', Mod: tea.ModCtrl})
	drive(t, m, cmd)
	b, _ = r.Load()
	if len(b.Tasks) != 3 {
		t.Errorf("tasks: %d, flash %q", len(b.Tasks), m.flash)
	}
}

func TestDecideFlow(t *testing.T) {
	r := scratch(t)
	res, _ := r.New(core.NewOpts{Summary: "fork"})
	id := res.Task.ID
	r.Block(id, "which?", []string{"this", "that"}, 2)
	m := newModel(r, ScreenDecide, "builtin_log_compact")
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	load(t, m)
	if !strings.Contains(m.View().Content, "which?") {
		t.Fatalf("question not shown: %q", m.View().Content)
	}
	press(t, m, "b", "enter") // an option's own letter jumps to it
	b, _ := r.Load()
	tk := b.ByID[id]
	if tk.Status != "todo" || !strings.Contains(tk.Msg.Detail, "DECIDED") || !strings.Contains(tk.Msg.Detail, "that") {
		t.Errorf("%+v", tk)
	}
	if m.decidedCount != 1 {
		t.Errorf("decided %d", m.decidedCount)
	}
	if !strings.Contains(m.View().Content, "Nothing waiting") {
		t.Errorf("queue not drained: %q", m.View().Content)
	}
}
