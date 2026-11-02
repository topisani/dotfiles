package tui

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"

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

func key(s string) tea.KeyPressMsg {
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
		_, cmd := m.Update(key(k))
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

	sizes := [][2]int{{0, 0}, {1, 1}, {10, 3}, {40, 10}, {89, 20}, {90, 20}, {200, 60}}
	modes := []mode{modeNormal, modeSearch, modePicker, modeInput, modeConfirm, modeNew, modeHelp, modeGraph, modeDecide, modeDecideText}
	for _, screen := range []Screen{ScreenBoard, ScreenDecide} {
		for _, sz := range sizes {
			m := newModel(r, screen, "builtin_log_compact")
			_ = m.View() // before anything arrives
			m.Update(tea.WindowSizeMsg{Width: sz[0], Height: sz[1]})
			load(t, m)
			m.pickOpts, m.pickAsk = core.Statuses, "x"
			for _, md := range modes {
				m.mode = md
				_ = m.View()
			}
		}
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
