package tui

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/textarea"
	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"

	"jt/internal/core"
)

// ---------------------------------------------------------------- new task

const (
	fieldSummary = iota
	fieldPriority
	fieldScope
	fieldNeeds
	fieldBody
	fieldCount
)

type newForm struct {
	summary, scope, needs textinput.Model
	body                  textarea.Model
	priority              int // index into core.Priorities; len = none
	focused               int
	blockerHint           string
}

func newNewForm(w, h int) newForm {
	f := newForm{priority: 2}
	f.summary, f.scope, f.needs = textinput.New(), textinput.New(), textinput.New()
	f.summary.Placeholder = "one line, what and why"
	f.summary.CharLimit = core.MaxSummary
	f.scope.Placeholder = "paths it should touch: this is what collision detection runs on"
	f.needs.Placeholder = "ids or words of blocking tasks"
	f.body = textarea.New()
	f.body.ShowLineNumbers = false
	f.body.Placeholder = "bug: reproduction, observed vs expected. feature: what and why, not how."
	f.resize(w, h)
	return f
}

func (f *newForm) resize(w, h int) {
	fw := max(min(w-22, 100), 20) // frame, label, prompt, cursor and the counter
	f.summary.SetWidth(fw)
	f.scope.SetWidth(fw)
	f.needs.SetWidth(fw)
	f.body.SetWidth(max(min(w-4, 110), 20))
	f.body.SetHeight(max(h-10, 3))
}

// counter shows how much of the summary limit is used, warming up towards it.
func (f *newForm) counter() string {
	n := utf8.RuneCountInString(f.summary.Value())
	s := fmt.Sprintf("%d/%d", n, core.MaxSummary)
	switch {
	case n >= core.MaxSummary:
		return redStyle.Render(s)
	case n >= core.MaxSummary-10:
		return yellowStyle.Render(s)
	}
	return dimStyle.Render(s)
}

func (f *newForm) focus() tea.Cmd {
	f.summary.Blur()
	f.scope.Blur()
	f.needs.Blur()
	f.body.Blur()
	switch f.focused {
	case fieldSummary:
		return f.summary.Focus()
	case fieldScope:
		return f.scope.Focus()
	case fieldNeeds:
		return f.needs.Focus()
	case fieldBody:
		return f.body.Focus()
	}
	return nil
}

func (f *newForm) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	switch f.focused {
	case fieldSummary:
		f.summary, cmd = f.summary.Update(msg)
	case fieldScope:
		f.scope, cmd = f.scope.Update(msg)
	case fieldNeeds:
		f.needs, cmd = f.needs.Update(msg)
	case fieldBody:
		f.body, cmd = f.body.Update(msg)
	}
	return cmd
}

func (m *Model) keyNew(k tea.KeyPressMsg) tea.Cmd {
	f := &m.form
	s := k.String()
	switch s {
	case "esc":
		m.mode = modeNormal
		return nil
	case "tab":
		f.focused = (f.focused + 1) % fieldCount
		return f.focus()
	case "shift+tab":
		f.focused = (f.focused + fieldCount - 1) % fieldCount
		return f.focus()
	case "ctrl+s":
		return m.submitNew()
	case "enter":
		if f.focused != fieldBody {
			f.focused = (f.focused + 1) % fieldCount
			return f.focus()
		}
	}
	if f.focused == fieldPriority {
		n := len(core.Priorities) + 1
		switch s {
		case "left", "h":
			f.priority = (f.priority + n - 1) % n
		case "right", "l", "space":
			f.priority = (f.priority + 1) % n
		case "0", "1", "2", "3":
			f.priority = int(s[0] - '0')
		}
		return nil
	}
	return f.update(k)
}

func (m *Model) submitNew() tea.Cmd {
	f := &m.form
	summary := strings.TrimSpace(f.summary.Value())
	if summary == "" {
		m.setFlash("a task needs a summary", true)
		f.focused = fieldSummary
		return f.focus()
	}
	o := core.NewOpts{Summary: summary, Scope: strings.TrimSpace(f.scope.Value()), Body: f.body.Value(),
		Blockers: strings.Fields(f.needs.Value())}
	if f.priority < len(core.Priorities) {
		o.Priority = core.Priorities[f.priority]
	}
	m.mode = modeNormal
	r := m.repo
	return m.act(func() (*core.Result, error) { return r.New(o) })
}

// ---------------------------------------------------------------- decide queue

const decideDeferAsk = "Defer: why? "

func (m *Model) decideQueue() []*core.Task {
	if m.board == nil {
		return nil
	}
	var out []*core.Task
	for _, t := range m.board.ByPriority(false) {
		if t.Status == "blocked" && !m.decideSkipped[t.ID] {
			out = append(out, t)
		}
	}
	return out
}

func (m *Model) decideCurrent() (*core.Task, *core.Fork) {
	q := m.decideQueue()
	if len(q) == 0 {
		return nil, nil
	}
	t := q[0]
	f := t.Msg.ParseFork()
	if f == nil {
		f = &core.Fork{Question: "(this task parks no recorded question)"}
	}
	return t, f
}

func (m *Model) leaveDecide() tea.Cmd {
	if m.standaloneDecide {
		return tea.Quit
	}
	m.mode = modeNormal
	return nil
}

func (m *Model) keyDecide(k tea.KeyPressMsg) tea.Cmd {
	s := k.String()
	t, f := m.decideCurrent()
	if s == "q" || s == "esc" {
		return m.leaveDecide()
	}
	if t == nil {
		return nil
	}
	switch {
	case key.Matches(k, keys.ScrollDown):
		m.decideView.HalfPageDown()
		return nil
	case key.Matches(k, keys.ScrollUp):
		m.decideView.HalfPageUp()
		return nil
	}
	r, id := m.repo, t.ID
	switch s {
	case "j", "down":
		m.decideIdx = max(min(m.decideIdx+1, len(f.Options)-1), 0)
	case "k", "up":
		m.decideIdx = max(m.decideIdx-1, 0)
	case "enter":
		if len(f.Options) == 0 {
			return m.openDecideText(false)
		}
		key := f.Options[min(m.decideIdx, len(f.Options)-1)].Key
		m.decideIdx = 0
		m.decidePending = true
		return m.act(func() (*core.Result, error) { return r.Decide(id, core.DecideOpts{Option: key}) })
	case "w":
		return m.openDecideText(false)
	case "m":
		return m.openDecideText(true)
	case "s":
		m.decideSkipped[id] = true
		m.decideIdx = 0
	case "d":
		return m.ask(decideDeferAsk, "", func(v string) tea.Cmd {
			m.decideIdx = 0
			return m.act(func() (*core.Result, error) { return r.Defer(id, v) })
		})
	default:
		// An option's own letter jumps to it.
		for i, o := range f.Options {
			if o.Key == s {
				m.decideIdx = i
			}
		}
	}
	return nil
}

func (m *Model) openDecideText(moot bool) tea.Cmd {
	m.mode = modeDecideText
	m.decideMoot = moot
	m.decideText.SetValue("")
	m.decideText.SetWidth(max(min(m.w-6, 90), 20))
	m.decideText.SetHeight(5)
	return m.decideText.Focus()
}

// keyDecideText takes a free-form answer, recorded as the whole decision.
func (m *Model) keyDecideText(k tea.KeyPressMsg) tea.Cmd {
	switch k.String() {
	case "esc":
		m.mode = modeDecide
		m.decideText.Blur()
		return nil
	case "ctrl+s":
		t, _ := m.decideCurrent()
		text := strings.TrimSpace(m.decideText.Value())
		if t == nil {
			m.mode = modeDecide
			return nil
		}
		if text == "" {
			m.setFlash("a decision needs text", true)
			return nil
		}
		m.mode = modeDecide
		m.decideText.Blur()
		m.decideIdx = 0
		m.decidePending = true
		r, id, moot := m.repo, t.ID, m.decideMoot
		return m.act(func() (*core.Result, error) { return r.Decide(id, core.DecideOpts{Text: text, Moot: moot}) })
	}
	var cmd tea.Cmd
	m.decideText, cmd = m.decideText.Update(k)
	return cmd
}
