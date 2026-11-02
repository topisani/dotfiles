package core

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync"
)

// TasksRevset is the coarse prefilter; ParseMessage has the final word. Anchored
// to line starts so prose about the format doesn't match. Keep in step with the
// `tasks()` alias in the jj config.
const TasksRevset = `description(regex:"(?m)^Task-Status:[ \t]")`

const openRevset = `description(regex:"(?m)^Task-Status:[ \t]*(todo|ready|doing|investigating|blocked|deferred)[ \t]*$")`

// Repo runs jj in one workspace. The workspace is the cwd on purpose: `jt start`
// claims *this* workspace's @, so which workspace you're in has to be a property
// of the process, not an argument someone can forget.
type Repo struct{ Dir string }

// run executes jj, retrying once through `update-stale` if another workspace's
// rewrite left this one stale — a routine state with parallel lanes, and not one
// an agent should have to diagnose.
func (r Repo) run(stdin string, args ...string) (string, error) {
	out, err := r.runOnce(stdin, args...)
	if err != nil && strings.Contains(err.Error(), "working copy is stale") {
		if _, e := r.runOnce("", "workspace", "update-stale", "--quiet"); e == nil {
			return r.runOnce(stdin, args...)
		}
	}
	return out, err
}

func (r Repo) runOnce(stdin string, args ...string) (string, error) {
	cmd := exec.Command("jj", append([]string{"--color=never"}, args...)...)
	cmd.Dir = r.Dir
	if stdin != "" {
		cmd.Stdin = strings.NewReader(stdin)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return stdout.String(), errors.New(msg)
	}
	return stdout.String(), nil
}

// read runs a query without snapshotting: reads must stay cheap and must not
// race a worker's edits. Callers that need a fresh tree call Snapshot first.
func (r Repo) read(args ...string) (string, error) {
	return r.run("", append(args, "--ignore-working-copy")...)
}

// Snapshot records the working copy. Without it `empty` is whatever the last jj
// command saw, which is how `done` used to warn "empty" right after an edit.
func (r Repo) Snapshot() error {
	_, err := r.run("", "util", "snapshot", "--quiet")
	return err
}

func (r Repo) Root() (string, error) {
	out, err := r.read("workspace", "root")
	return strings.TrimSpace(out), err
}

func (r Repo) IsRepo() bool {
	_, err := r.Root()
	return err == nil
}

// OpID identifies the repo's state; the TUI polls it to notice other sessions.
func (r Repo) OpID() (string, error) {
	out, err := r.read("op", "log", "-n1", "--no-graph", "-T", `id.short(16)`)
	return strings.TrimSpace(out), err
}

func (r Repo) Undo() error {
	_, err := r.run("", "undo", "--quiet")
	return err
}

// Config reads a jj config value, "" if unset. jt.verify and jt.setup live in the
// repo's jj config so they apply in every workspace without touching the tree.
func (r Repo) Config(key string) string {
	out, err := r.read("config", "get", key)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(out)
}

func (r Repo) SetConfig(key, value string) error {
	_, err := r.run("", "config", "set", "--repo", key, value)
	return err
}

// Task is one row of the board. The first block of fields is the stable JSON
// contract; omitempty keeps the polled `-q` form small.
type Task struct {
	ID       string `json:"id"`
	Status   string `json:"status"`
	Priority string `json:"priority"`
	Scope    string `json:"scope"`
	Summary  string `json:"summary"`
	Needs    string `json:"needs"` // unfinished blockers, space-separated
	Ready    bool   `json:"ready"`
	Empty    bool   `json:"empty"`

	Workspaces []string `json:"workspaces,omitempty"` // workspaces whose @ this is
	Orphaned   bool     `json:"orphaned,omitempty"`   // doing, but nobody's @
	Collides   []string `json:"collides,omitempty"`   // doing tasks with overlapping scope
	Conflict   bool     `json:"conflict,omitempty"`
	Divergent  bool     `json:"divergent,omitempty"`
	Immutable  bool     `json:"immutable,omitempty"`
	Fork       *Fork    `json:"fork,omitempty"` // the open question, when blocked
	Body       *string  `json:"body,omitempty"`

	FullID   string   `json:"-"`
	CommitID string   `json:"-"`
	Parents  []string `json:"-"`
	Current  bool     `json:"-"` // this workspace's @
	Updated  string   `json:"-"`
	Msg      Message  `json:"-"`

	// Filled by FillStats only: Load is polled, and these need a diff per task.
	Added, Removed, Files int `json:"-"`
}

// Brief returns a copy without the fields a polling caller shouldn't pay for.
func (t Task) Brief() Task {
	t.Body, t.Fork = nil, nil
	return t
}

// Full fills in the body and open question.
func (t Task) Full() Task {
	b := t.Msg.Detail
	t.Body = &b
	if t.Status == "blocked" {
		t.Fork = t.Msg.ParseFork()
	}
	return t
}

// NeedsList is Needs as a slice.
func (t Task) NeedsList() []string { return strings.Fields(t.Needs) }

// PriorityRank orders tasks: P0 first, unprioritised last.
func (t Task) PriorityRank() string {
	if t.Priority == "" {
		return "~"
	}
	return t.Priority
}

var idPrefixes sync.Map // short change id -> length of its unique prefix

// SplitID splits a short change id into jj's unique prefix and the rest, the
// way jj colors them. An id jt hasn't loaded comes back whole as the prefix.
func SplitID(id string) (prefix, rest string) {
	if n, ok := idPrefixes.Load(id); ok {
		if n := n.(int); n <= len(id) {
			return id[:n], id[n:]
		}
	}
	return id, ""
}

// Board is every task in graph order (blockers before dependents).
type Board struct {
	Tasks      []*Task
	ByID       map[string]*Task
	Workspaces map[string]string // workspace name -> change id of its @
}

const taskTemplate = `"{\"id\":" ++ json(stringify(change_id.shortest(8))) ++
  ",\"prefix\":" ++ change_id.shortest(8).prefix().len() ++
  ",\"full\":" ++ json(stringify(change_id)) ++
  ",\"commit\":" ++ json(stringify(commit_id.short(12))) ++
  ",\"parents\":" ++ json(stringify(parents.map(|p| p.change_id().shortest(8)).join(" "))) ++
  ",\"empty\":" ++ if(empty,"true","false") ++
  ",\"conflict\":" ++ if(conflict,"true","false") ++
  ",\"divergent\":" ++ if(divergent,"true","false") ++
  ",\"immutable\":" ++ if(immutable,"true","false") ++
  ",\"current\":" ++ if(current_working_copy,"true","false") ++
  ",\"updated\":" ++ json(stringify(committer.timestamp().local().format("%Y-%m-%d %H:%M"))) ++
  ",\"desc\":" ++ json(description) ++ "}\n"`

type rawTask struct {
	ID, Full, Commit, Parents, Updated, Desc string
	Prefix                                   int
	Empty, Conflict, Divergent, Immutable    bool
	Current                                  bool
}

// Load reads the whole board.
func (r Repo) Load() (*Board, error) {
	out, err := r.read("log", "-r", TasksRevset, "--no-graph", "--reversed", "-T", taskTemplate)
	if err != nil {
		return nil, err
	}
	b := &Board{ByID: map[string]*Task{}, Workspaces: map[string]string{}}
	for _, line := range strings.Split(out, "\n") {
		if line == "" {
			continue
		}
		var raw rawTask
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			return nil, fmt.Errorf("parsing jj output: %w", err)
		}
		m := ParseMessage(raw.Desc)
		status := m.Get(KeyStatus)
		if status == "" {
			continue // the substring was in the body, not the trailer block
		}
		t := &Task{
			ID: raw.ID, Status: status, Priority: m.Get(KeyPriority), Scope: m.Get(KeyScope),
			Summary: m.Subject, Empty: raw.Empty, Conflict: raw.Conflict, Divergent: raw.Divergent,
			Immutable: raw.Immutable, FullID: raw.Full, CommitID: raw.Commit, Current: raw.Current,
			Parents: strings.Fields(raw.Parents), Updated: raw.Updated, Msg: m,
		}
		idPrefixes.Store(raw.ID, raw.Prefix)
		if prev, dup := b.ByID[t.ID]; dup { // divergent: two commits, one change id
			prev.Divergent = true
			continue
		}
		b.Tasks = append(b.Tasks, t)
		b.ByID[t.ID] = t
	}

	wsOut, err := r.read("workspace", "list", "-T", `name ++ "\t" ++ target.change_id().shortest(8) ++ "\n"`)
	if err != nil {
		return nil, err
	}
	for _, line := range strings.Split(wsOut, "\n") {
		if name, id, ok := strings.Cut(line, "\t"); ok {
			b.Workspaces[name] = id
			if t := b.ByID[id]; t != nil {
				t.Workspaces = append(t.Workspaces, name)
			}
		}
	}
	b.derive()
	return b, nil
}

func finished(status string) bool { return status == "done" || status == "testing" }

func (b *Board) derive() {
	var doing []*Task
	for _, t := range b.Tasks {
		if t.Status == "doing" {
			doing = append(doing, t)
			t.Orphaned = len(t.Workspaces) == 0
		}
	}
	for _, t := range b.Tasks {
		var needs []string
		for _, p := range t.Parents {
			if pt := b.ByID[p]; pt != nil && !finished(pt.Status) {
				needs = append(needs, p)
			}
		}
		t.Needs = strings.Join(needs, " ")
		t.Ready = len(needs) == 0 && (t.Status == "todo" || t.Status == "ready")
		if t.Ready {
			for _, d := range doing {
				if ScopesOverlap(t.Scope, d.Scope) {
					t.Collides = append(t.Collides, d.ID)
				}
			}
		}
	}
}

// ByPriority returns tasks in priority order, graph order within a priority:
// graph order alone is unstable because rewriting a task bumps its commit time.
func (b *Board) ByPriority(includeDone bool) []*Task {
	var out []*Task
	for _, t := range b.Tasks {
		if includeDone || t.Status != "done" {
			out = append(out, t)
		}
	}
	slices.SortStableFunc(out, func(a, c *Task) int { return strings.Compare(a.PriorityRank(), c.PriorityRank()) })
	return out
}

// Dependents returns tasks with t as a direct parent.
func (b *Board) Dependents(id string) []*Task {
	var out []*Task
	for _, t := range b.Tasks {
		if slices.Contains(t.Parents, id) {
			out = append(out, t)
		}
	}
	return out
}

// Resolve turns a change-id prefix or words from a summary into one task. Tiers
// keep an incidental summary hit from shadowing a real id. Queries are literal.
func (b *Board) Resolve(q string) (*Task, error) {
	if q == "" {
		return nil, errors.New("no task given")
	}
	if t := b.ByID[q]; t != nil {
		return t, nil
	}
	var byID, bySummary []*Task
	lq := strings.ToLower(q)
	for _, t := range b.Tasks {
		if strings.HasPrefix(t.FullID, q) {
			byID = append(byID, t)
		} else if strings.Contains(strings.ToLower(t.Summary), lq) {
			bySummary = append(bySummary, t)
		}
	}
	hits := byID
	if len(hits) == 0 {
		hits = bySummary
		if len(hits) > 1 { // prefer the one still open over old finished namesakes
			open := slices.DeleteFunc(slices.Clone(hits), func(t *Task) bool { return t.Status == "done" })
			if len(open) > 0 {
				hits = open
			}
		}
	}
	switch len(hits) {
	case 0:
		return nil, fmt.Errorf("no task matches '%s'", q)
	case 1:
		return hits[0], nil
	}
	var b2 strings.Builder
	fmt.Fprintf(&b2, "'%s' is ambiguous:", q)
	for _, t := range hits {
		fmt.Fprintf(&b2, "\n  %s [%s] %s", t.ID, t.Status, t.Summary)
	}
	return nil, errors.New(b2.String())
}

// NextOpts narrows Next.
type NextOpts struct {
	Limit    int
	Focus    string
	Disjoint bool // picks must not overlap each other either (parallel dispatch)
}

// Skipped explains a ready task Next left out.
type Skipped struct {
	ID     string `json:"id"`
	Reason string `json:"reason"`
}

// Next is the selection rule that used to be prose in every skill: highest
// priority ready tasks whose scope doesn't overlap something in flight.
func (b *Board) Next(o NextOpts) (picks []*Task, skipped []Skipped) {
	terms := strings.Fields(strings.ToLower(o.Focus))
	var taken []string
	for _, t := range b.ByPriority(false) {
		if !t.Ready {
			continue
		}
		if !focusMatches(t, terms) {
			continue
		}
		if len(t.Collides) > 0 {
			skipped = append(skipped, Skipped{t.ID, "scope overlaps doing " + strings.Join(t.Collides, " ")})
			continue
		}
		if o.Limit > 0 && len(picks) >= o.Limit {
			skipped = append(skipped, Skipped{t.ID, "over the limit"})
			continue
		}
		if o.Disjoint && slices.ContainsFunc(taken, func(s string) bool { return ScopesOverlap(s, t.Scope) }) {
			skipped = append(skipped, Skipped{t.ID, "scope overlaps an earlier pick"})
			continue
		}
		picks = append(picks, t)
		taken = append(taken, t.Scope)
	}
	return
}

// focusMatches requires every term in the text, or as an id prefix. Never as an id
// substring: change ids are random letters, so short words would match by chance.
func focusMatches(t *Task, terms []string) bool {
	hay := strings.ToLower(t.Summary + " " + t.Scope + " " + t.Priority)
	for _, term := range terms {
		if !strings.Contains(hay, term) && !strings.HasPrefix(t.FullID, term) {
			return false
		}
	}
	return true
}

// Lane is a section of the human-facing board.
type Lane struct {
	Name  string
	Tasks []*Task
}

// Lanes groups the board by what, if anything, it's waiting on.
func (b *Board) Lanes() []Lane {
	lanes := []Lane{{Name: "In flight"}, {Name: "Needs you"}, {Name: "Ready"}, {Name: "Waiting"}, {Name: "Deferred"}, {Name: "Done"}}
	for _, t := range b.ByPriority(true) {
		i := 3
		switch {
		case t.Status == "doing", t.Status == "investigating":
			i = 0
		case t.Status == "blocked", t.Status == "testing":
			i = 1
		case t.Ready:
			i = 2
		case t.Status == "deferred":
			i = 4
		case t.Status == "done":
			i = 5
		}
		lanes[i].Tasks = append(lanes[i].Tasks, t)
	}
	return lanes
}

// Problem is a board inconsistency. Error-level ones mean the board can't be
// trusted as-is; warnings are worth a look.
type Problem struct {
	ID     string `json:"id"`
	Kind   string `json:"kind"`
	Level  string `json:"level"` // error | warn
	Detail string `json:"detail"`
}

// Check is what orchestrators used to eyeball on every loop.
func (b *Board) Check() []Problem {
	var out []Problem
	add := func(t *Task, kind, level, format string, args ...any) {
		out = append(out, Problem{t.ID, kind, level, fmt.Sprintf(format, args...)})
	}
	for _, t := range b.Tasks {
		if !ValidStatus(t.Status) {
			add(t, "unknown-status", "error", "status %q is not one of %s", t.Status, strings.Join(Statuses, " "))
		}
		if err := CheckSummary(t.Summary); err != nil {
			add(t, "long-summary", "warn", "%v", err)
		}
		if t.Orphaned {
			add(t, "orphaned", "error", "doing, but no workspace is on it — worker died or never closed out; `jt reap` resets it")
		}
		if t.Conflict {
			add(t, "conflict", "error", "has unresolved conflicts")
		}
		if t.Divergent {
			add(t, "divergent", "error", "two commits share this change id — likely a concurrent rewrite; `jj log -r 'change_id(%s)'`", t.ID)
		}
		if t.Immutable && t.Status != "done" {
			add(t, "immutable", "warn", "open task is immutable, so jt can't update it")
		}
		if t.Status == "done" && t.Empty {
			add(t, "empty-done", "warn", "done with no code — fine if moot, otherwise a worker misfired")
		}
		if t.Status == "blocked" && t.Msg.ParseFork() == nil {
			add(t, "no-question", "warn", "blocked with no recorded question")
		}
		if t.Ready && t.Scope == "" {
			add(t, "no-scope", "warn", "ready with no scope, so collisions can't be detected")
		}
	}
	return out
}

// HasErrors reports whether any problem is error-level.
func HasErrors(ps []Problem) bool {
	return slices.ContainsFunc(ps, func(p Problem) bool { return p.Level == "error" })
}

// StateDir is where logs go.
func StateDir(sub string) string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(base, "jt", sub)
}
