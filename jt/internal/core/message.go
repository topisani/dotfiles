// Package core is jt's domain layer: the description format, the board, and
// every operation on them. The CLI and the TUI are both thin shells over it, so
// a rule enforced here (say, "don't start a task with an unfinished blocker")
// holds for agents and humans alike.
package core

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

// Trailer keys jt owns. Everything else in a trailer block (Co-Authored-By,
// Change-Id, ...) belongs to someone else and is preserved verbatim, including
// repeated keys.
const (
	KeyStatus   = "Task-Status"
	KeyPriority = "Priority"
	KeyScope    = "Scope"
	KeyReclaims = "Task-Reclaims"
)

var managedKeys = []string{KeyStatus, KeyPriority, KeyScope, KeyReclaims}

// Statuses in lifecycle order.
var Statuses = []string{"todo", "ready", "doing", "investigating", "blocked", "testing", "deferred", "done"}

// Priorities offered by pickers and completions; the field itself is free-form.
var Priorities = []string{"P0", "P1", "P2", "P3"}

func ValidStatus(s string) bool {
	for _, v := range Statuses {
		if v == s {
			return true
		}
	}
	return false
}

type Trailer struct{ Key, Value string }

// Message is a parsed change description: subject line, free-form detail, and
// the trailer block.
type Message struct {
	Subject  string
	Detail   string
	Trailers []Trailer
}

var trailerRE = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9-]*:[ \t]`)

func blank(s string) bool { return strings.TrimSpace(s) == "" }

// ParseMessage splits a description. The trailer block is the last paragraph,
// and only if every line of it is `Key: value` — so a task that merely mentions
// "Task-Status: done" in its body is never misfiled. As in git (and in jj's own
// `trailers` keyword, which renders the graph) the first paragraph is the
// subject and never a trailer block: "Fix: the thing" is a summary.
func ParseMessage(desc string) Message {
	lines := strings.Split(desc, "\n")
	n := len(lines)
	for n > 0 && blank(lines[n-1]) {
		n--
	}
	lines = lines[:n]
	if n == 0 {
		return Message{}
	}
	start := n
	for start > 0 && !blank(lines[start-1]) {
		start--
	}
	var m Message
	body := lines
	if start > 0 {
		isBlock := true
		for _, l := range lines[start:] {
			if !trailerRE.MatchString(l) {
				isBlock = false
				break
			}
		}
		if isBlock {
			for _, l := range lines[start:] {
				k, v, _ := strings.Cut(l, ":")
				m.Trailers = append(m.Trailers, Trailer{k, strings.TrimSpace(v)})
			}
			body = lines[:start]
		}
	}
	for len(body) > 0 && blank(body[len(body)-1]) {
		body = body[:len(body)-1]
	}
	if len(body) > 0 {
		m.Subject = body[0]
		m.Detail = strings.TrimSpace(strings.Join(body[1:], "\n"))
	}
	return m
}

// Above is the part of the message above the trailer block.
func (m Message) Above() string {
	if m.Detail == "" {
		return m.Subject
	}
	return m.Subject + "\n\n" + m.Detail
}

func (m Message) String() string {
	var b strings.Builder
	b.WriteString(m.Above())
	b.WriteString("\n")
	if len(m.Trailers) > 0 {
		b.WriteString("\n")
		for _, t := range m.Trailers {
			fmt.Fprintf(&b, "%s: %s\n", t.Key, t.Value)
		}
	}
	return b.String()
}

// Get returns the last value for key, case-insensitively.
func (m Message) Get(key string) string {
	for i := len(m.Trailers) - 1; i >= 0; i-- {
		if strings.EqualFold(m.Trailers[i].Key, key) {
			return m.Trailers[i].Value
		}
	}
	return ""
}

// Set replaces key's value in place, or appends it. An empty value deletes it.
func (m *Message) Set(key, value string) {
	out := m.Trailers[:0:0]
	placed := false
	for _, t := range m.Trailers {
		if !strings.EqualFold(t.Key, key) {
			out = append(out, t)
		} else if value != "" && !placed {
			out = append(out, Trailer{t.Key, value})
			placed = true
		}
	}
	if value != "" && !placed {
		out = append(out, Trailer{key, value})
	}
	m.Trailers = out
}

// Strip removes jt's trailers, leaving everyone else's.
func (m *Message) Strip() {
	for _, k := range managedKeys {
		m.Set(k, "")
	}
}

// SetAbove replaces subject and detail from one block of text.
func (m *Message) SetAbove(text string) {
	head, rest, _ := strings.Cut(strings.TrimSpace(text), "\n")
	m.Subject = strings.TrimSpace(head)
	m.Detail = strings.TrimSpace(rest)
}

// SetBody replaces the detail, keeping the subject — `body` means the same thing
// here as in `jt json`, so reading a body and writing it back can't destroy the
// title. A caller that fed back the whole message (subject included, as `jt show`
// prints it) gets the duplicate subject dropped rather than pushed into the body.
func (m *Message) SetBody(text string) {
	text = strings.TrimSpace(text)
	if head, rest, _ := strings.Cut(text, "\n"); strings.TrimSpace(head) == m.Subject {
		text = strings.TrimSpace(rest)
	}
	m.Detail = text
}

func (m *Message) appendSection(section string) {
	if m.Detail != "" {
		m.Detail += "\n\n"
	}
	m.Detail += section
}

// Section markers in the detail. They are plain text so a description stays a
// readable commit message; each section is appended at the end and runs to the
// next marker, so an open question can be multi-paragraph.
var sectionRE = regexp.MustCompile(`^(BLOCKED:|DEFERRED:|TESTING:|DECIDED\b|REOPENED\b)`)

// Option is one choice of a parked design fork.
type Option struct {
	Key         string `json:"key"`
	Text        string `json:"text"`
	Recommended bool   `json:"recommended,omitempty"`
}

// Fork is the open question a BLOCKED section carries.
type Fork struct {
	Question string   `json:"question"`
	Options  []Option `json:"options,omitempty"`
}

var (
	optionRE      = regexp.MustCompile(`^\s*(?:[-*]\s+)?\(?([a-zA-Z0-9])\)\s+(.+)$`)
	recommendedRE = regexp.MustCompile(`(?i)\s*\(recommended\)\s*$`)
)

// blockedRange finds the last BLOCKED section as a half-open line range.
func blockedRange(lines []string) (int, int) {
	from := -1
	for i, l := range lines {
		if strings.HasPrefix(l, "BLOCKED:") {
			from = i
		}
	}
	if from < 0 {
		return -1, -1
	}
	to := len(lines)
	for i := from + 1; i < len(lines); i++ {
		if sectionRE.MatchString(lines[i]) {
			to = i
			break
		}
	}
	return from, to
}

// ParseFork extracts the open question, or nil if the task parks none.
func (m Message) ParseFork() *Fork {
	lines := strings.Split(m.Detail, "\n")
	from, to := blockedRange(lines)
	if from < 0 {
		return nil
	}
	f := &Fork{}
	var q []string
	for i, l := range lines[from:to] {
		if i == 0 {
			q = append(q, strings.TrimSpace(strings.TrimPrefix(l, "BLOCKED:")))
			continue
		}
		if o := optionRE.FindStringSubmatch(l); o != nil {
			text := recommendedRE.ReplaceAllString(o[2], "")
			f.Options = append(f.Options, Option{o[1], text, text != o[2]})
			continue
		}
		q = append(q, l)
	}
	f.Question = strings.TrimSpace(strings.Join(q, "\n"))
	return f
}

// FormatFork renders a question and its options as a BLOCKED section. recommend
// is a 1-based option index, 0 for none.
func FormatFork(question string, options []string, recommend int) string {
	var b strings.Builder
	b.WriteString("BLOCKED: " + strings.TrimSpace(question))
	for i, o := range options {
		fmt.Fprintf(&b, "\n  %c) %s", 'a'+rune(i), strings.TrimSpace(o))
		if i+1 == recommend {
			b.WriteString(" (recommended)")
		}
	}
	return b.String()
}

// removeBlocked drops every BLOCKED section: once decided, a future reader should
// see the resolution, not the debate (`jt evo` keeps the original either way).
func (m *Message) removeBlocked() {
	for {
		lines := strings.Split(m.Detail, "\n")
		from, to := blockedRange(lines)
		if from < 0 {
			break
		}
		m.Detail = strings.TrimSpace(strings.Join(append(lines[:from:from], lines[to:]...), "\n"))
	}
}

func today() string { return time.Now().Format("2006-01-02") }

// Checklist counts `- [x]` and `- [ ]` items in the text.
func Checklist(s string) (done, total int) {
	for _, l := range strings.Split(s, "\n") {
		l = strings.TrimSpace(l)
		switch {
		case strings.HasPrefix(l, "- [x]"), strings.HasPrefix(l, "- [X]"):
			done++
			total++
		case strings.HasPrefix(l, "- [ ]"):
			total++
		}
	}
	return
}

// ScopesOverlap reports whether two Scope values can touch the same file.
// Entries are comma- or space-separated paths; a directory covers what's under
// it and a glob is reduced to its literal prefix. Empty scope means unknown,
// which is not a collision (`jt check` flags it instead).
func ScopesOverlap(a, b string) bool {
	for _, x := range scopePaths(a) {
		for _, y := range scopePaths(b) {
			if x == "" || y == "" || x == y || strings.HasPrefix(x, y+"/") || strings.HasPrefix(y, x+"/") {
				return true
			}
		}
	}
	return false
}

// scopePaths normalises a Scope value; "" stands for the whole tree.
func scopePaths(s string) []string {
	var out []string
	for _, p := range strings.FieldsFunc(s, func(r rune) bool { return r == ',' || r == ' ' || r == '\t' }) {
		if i := strings.IndexAny(p, "*?["); i >= 0 {
			p = p[:i]
		}
		p = strings.TrimRight(strings.TrimPrefix(p, "./"), "/")
		if p == "." {
			p = ""
		}
		out = append(out, p)
	}
	return out
}
