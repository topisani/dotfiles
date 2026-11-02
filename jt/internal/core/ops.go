package core

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Result is what a mutation reports. Warnings are things the caller must see but
// that didn't stop the operation.
type Result struct {
	Task     *Task    `json:"task,omitempty"`
	Warnings []string `json:"warnings,omitempty"`
	Note     string   `json:"note,omitempty"`
}

func (r Repo) resolve(q string) (*Board, *Task, error) {
	b, err := r.Load()
	if err != nil {
		return nil, nil, err
	}
	t, err := b.Resolve(q)
	return b, t, err
}

func (r Repo) describe(id string, m Message) error {
	_, err := r.run(m.String(), "describe", id, "--stdin", "--quiet")
	return err
}

func (r Repo) result(id string, note string, warns ...string) (*Result, error) {
	b, err := r.Load()
	if err != nil {
		return nil, err
	}
	res := &Result{Task: b.ByID[id], Note: note, Warnings: warns}
	if res.Task != nil && res.Task.Conflict {
		res.Warnings = append(res.Warnings, id+" has conflicts — resolve them before anything else")
	}
	return res, nil
}

// Tip is the revision new work should build on, seen from a workspace's @ ("" is
// this workspace). Open tasks don't count: their code isn't finished. Done and
// testing tasks do — their code is buildable-on, which is what makes a run
// accumulate as one line. Empty commits don't: an undescribed one is jj's scratch
// working copy, and an empty task (moot, or still a placeholder) is no work.
func (r Repo) Tip(workspace string) (string, error) {
	rev := "@"
	if workspace != "" {
		rev = workspace + "@"
	}
	set := fmt.Sprintf(`heads(::%s ~ %s ~ (empty() & (description(exact:"") | %s)))`, rev, openRevset, TasksRevset)
	out, err := r.read("log", "-r", set, "--no-graph", "-T", `change_id.shortest(8) ++ "\n"`)
	if err != nil {
		return "", err
	}
	if id, _, _ := strings.Cut(out, "\n"); id != "" {
		return id, nil
	}
	// Everything excluded (fresh repo, @ on root): fall back to @ itself.
	out, err = r.read("log", "-r", rev, "--no-graph", "-T", `change_id.shortest(8)`)
	return strings.TrimSpace(out), err
}

// NewOpts files a task.
type NewOpts struct {
	Summary, Body, Priority, Scope string
	Blockers                       []string // ids or words
	Parents                        []string // raw revisions
}

// New files a task. With no blockers it hangs off the work tip, so its parent
// pins the code it was filed against.
func (r Repo) New(o NewOpts) (*Result, error) {
	if strings.TrimSpace(o.Summary) == "" {
		return nil, errors.New("a task needs a summary")
	}
	parents := slices.Clone(o.Parents)
	if len(o.Blockers) > 0 {
		b, err := r.Load()
		if err != nil {
			return nil, err
		}
		for _, q := range o.Blockers {
			t, err := b.Resolve(q)
			if err != nil {
				return nil, err
			}
			parents = append(parents, t.ID)
		}
	}
	if len(parents) == 0 {
		tip, err := r.Tip("")
		if err != nil {
			return nil, err
		}
		parents = []string{tip}
	}
	m := Message{Subject: strings.TrimSpace(o.Summary), Detail: strings.TrimSpace(o.Body)}
	m.Set(KeyStatus, "todo")
	m.Set(KeyPriority, o.Priority)
	m.Set(KeyScope, o.Scope)

	args := append([]string{"new"}, parents...)
	args = append(args, "--no-edit", "-m", m.String(), "--config", "templates.commit_summary=change_id.shortest(8)")
	id, err := r.newChange(args)
	if err != nil {
		return nil, err
	}
	return r.result(id, "filed")
}

var createdRE = regexp.MustCompile(`Created new commit (\S+)`)

// newChange runs `jj new`, whose only report of the new id is on stderr.
func (r Repo) newChange(args []string) (string, error) {
	cmd := exec.Command("jj", append([]string{"--color=never"}, args...)...)
	cmd.Dir = r.Dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", errors.New(strings.TrimSpace(string(out)))
	}
	m := createdRE.FindStringSubmatch(string(out))
	if m == nil {
		return "", fmt.Errorf("could not determine new task id from: %s", out)
	}
	return m[1], nil
}

// SetOpts is a generic field update. Keys are case-insensitive; `status`,
// `priority`, `scope` are aliases, `body` is the detail below the summary,
// `summary` the first line, `message` everything above the trailers, and any
// other key is a trailer. An empty value clears.
func (r Repo) Set(q string, kvs [][2]string) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	m := t.Msg
	for _, kv := range kvs {
		k, v := kv[0], kv[1]
		switch strings.ToLower(k) {
		case "status", "task-status":
			if !ValidStatus(v) {
				return nil, fmt.Errorf("status must be one of: %s", strings.Join(Statuses, " "))
			}
			m.Set(KeyStatus, v)
		case "priority", "prio":
			m.Set(KeyPriority, v)
		case "scope":
			m.Set(KeyScope, v)
		case "body":
			m.SetBody(v)
		case "summary":
			if blank(v) {
				return nil, errors.New("summary can't be empty")
			}
			m.Subject = strings.TrimSpace(v)
		case "message":
			if blank(v) {
				return nil, errors.New("message can't be empty")
			}
			m.SetAbove(v)
		default:
			m.Set(k, v)
		}
	}
	if m.Get(KeyStatus) == "" {
		return nil, errors.New("refusing to clear the status: `jt strip` is how a task leaves the board")
	}
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "updated")
}

// StartOpts claims a task.
type StartOpts struct {
	Force    bool
	NoRebase bool
	Base     string // build on this workspace's tip rather than our own
	In       string // refuse unless run from this workspace
}

// Start claims a task: rebase onto the work tip, mark doing, make it @. It is the
// one gate every worker passes through, so the rules live here rather than in
// the prose of each skill.
func (r Repo) Start(q string, o StartOpts) (*Result, error) {
	// A worker whose cwd didn't persist between shell calls would otherwise seize
	// the @ of whichever workspace it landed in, usually the user's. Checked first
	// and not waivable by --force: this is never the intent.
	if o.In != "" {
		if err := r.checkWorkspace(o.In); err != nil {
			return nil, err
		}
	}
	b, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	if t.Status == "doing" && t.Current {
		return r.result(t.ID, "already yours")
	}
	if !o.Force {
		if err := t.startable(); err != nil {
			return nil, err
		}
	}
	if t.Immutable {
		return nil, fmt.Errorf("%s is immutable", t.ID)
	}
	var warns []string
	note := "now @ (status doing)"
	if t.Status == "doing" && t.Orphaned {
		warns = append(warns, "reclaiming a task no workspace was on")
	}
	if !o.NoRebase {
		tip, w, err := r.rebaseForStart(b, t, o.Base)
		if err != nil {
			return nil, err
		}
		warns = append(warns, w...)
		if tip != "" {
			note += ", rebased onto " + tip
		}
	}
	m := t.Msg
	m.Set(KeyStatus, "doing")
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	if _, err := r.run("", "edit", t.ID, "--quiet"); err != nil {
		return nil, err
	}
	return r.result(t.ID, note, warns...)
}

func (r Repo) checkWorkspace(name string) error {
	want, err := r.read("workspace", "root", "--name", name)
	if err != nil {
		return fmt.Errorf("no workspace named %s: %w", name, err)
	}
	here, err := r.Root()
	if err != nil {
		return err
	}
	if strings.TrimSpace(want) != here {
		return fmt.Errorf("this is %s, not workspace %s: nothing was claimed. Run from there: cd %s && jt start ...", here, name, strings.TrimSpace(want))
	}
	return nil
}

func (t *Task) startable() error {
	switch t.Status {
	case "done", "testing":
		return fmt.Errorf("%s is %s; `jt reopen` it first", t.ID, t.Status)
	case "deferred":
		return fmt.Errorf("%s is deferred — shelved on purpose; `jt set %s status=todo` to revive it", t.ID, t.ID)
	case "blocked":
		return fmt.Errorf("%s is blocked on a decision; see `jt decide`", t.ID)
	case "doing":
		if len(t.Workspaces) > 0 {
			return fmt.Errorf("%s is already claimed by workspace %s", t.ID, strings.Join(t.Workspaces, ", "))
		}
	}
	if t.Needs != "" {
		return fmt.Errorf("%s needs %s, which isn't finished; rebasing would silently drop that edge", t.ID, t.Needs)
	}
	return nil
}

// rebaseForStart moves the task onto the tip, returning the tip if it moved.
func (r Repo) rebaseForStart(b *Board, t *Task, base string) (rebasedOnto string, warns []string, err error) {
	tip, err := r.Tip(base)
	if err != nil {
		return "", nil, err
	}
	if t.ID == tip || (len(t.Parents) == 1 && t.Parents[0] == tip) {
		return "", nil, nil
	}
	// Already an ancestor of the tip: there is nowhere to move it.
	out, err := r.read("log", "-r", fmt.Sprintf("%s & ::%s", t.ID, tip), "--no-graph", "-T", `"x"`)
	if err != nil {
		return "", nil, err
	}
	if out != "" {
		return "", nil, nil
	}
	for _, p := range t.Parents {
		if pt := b.ByID[p]; pt != nil {
			in, err := r.read("log", "-r", fmt.Sprintf("%s & ::%s", p, tip), "--no-graph", "-T", `"x"`)
			if err == nil && in == "" {
				warns = append(warns, fmt.Sprintf("parent %s (%s) isn't in this line, so its code won't be here", p, pt.Status))
			}
		}
	}
	// -s, not -r: -r would reparent dependents onto our old parent and silently
	// erase their blocker edge.
	if _, err := r.run("", "rebase", "-s", t.ID, "-o", tip, "--quiet"); err != nil {
		return "", nil, fmt.Errorf("could not rebase %s onto %s (use --no-rebase to work it where it sits): %w", t.ID, tip, err)
	}
	return tip, warns, nil
}

// Done marks a task done. Empty is a warning, not a refusal, because a task made
// moot legitimately has no code; `Finish` is the gated path for real work.
func (r Repo) Done(q string) (*Result, error) {
	if err := r.Snapshot(); err != nil {
		return nil, err
	}
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	m := t.Msg
	m.Set(KeyStatus, "done")
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	var warns []string
	if t.Empty {
		warns = append(warns, t.ID+" is empty (no code changes)")
	}
	return r.result(t.ID, "marked done; `jt strip` finishes it", warns...)
}

// FinishOpts closes out a worked task.
type FinishOpts struct {
	Message    string // replaces everything above the trailers; "" keeps it
	Testing    string // what the user should check: ends at testing, not done
	NoVerify   bool
	AllowEmpty bool
}

// VerifyFailed is returned when the verify gate fails.
type VerifyFailed struct{ Report VerifyReport }

func (e *VerifyFailed) Error() string { return "verify failed: " + e.Report.Command }

// Finish is the worker's close-out as one operation, replacing the sequence
// `verify && jj describe && jt done` — where a bare `jj describe -m` destroys the
// trailers and leaves the task unfindable. All checks run before anything is
// written, so a failure leaves the task exactly as it was.
func (r Repo) Finish(q string, o FinishOpts) (*Result, error) {
	if err := r.Snapshot(); err != nil {
		return nil, err
	}
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	if t.Empty && !o.AllowEmpty {
		return nil, fmt.Errorf("%s has no code changes — did the worker misfire? (new files need `jj file track`; --allow-empty if intended)", t.ID)
	}
	if t.Conflict {
		return nil, fmt.Errorf("%s has unresolved conflicts", t.ID)
	}
	var warns []string
	if !o.NoVerify {
		cmd := r.Config("jt.verify")
		switch {
		case cmd == "":
			warns = append(warns, "no verify command configured (`jt verify --set <cmd>`), so this was not verified")
		case !t.Current:
			return nil, fmt.Errorf("%s isn't this workspace's @, so verify would test the wrong tree (--no-verify if you verified elsewhere)", t.ID)
		default:
			rep, err := r.Verify()
			if err != nil {
				return nil, err
			}
			if !rep.OK {
				return nil, &VerifyFailed{*rep}
			}
		}
	}
	if t.Current {
		if un := r.Untracked(); len(un) > 0 {
			warns = append(warns, "untracked, so NOT in this commit: "+strings.Join(un, " "))
		}
	}
	m := t.Msg
	if o.Message != "" {
		m.SetAbove(o.Message)
	}
	status := "done"
	if o.Testing != "" {
		status = "testing"
		m.appendSection("TESTING: " + strings.TrimSpace(o.Testing))
	}
	m.Set(KeyStatus, status)
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "finished ("+status+")", warns...)
}

// Untracked lists working-copy paths jj isn't tracking. With auto-track off, a
// new file silently missing from the commit is the classic way to "finish" a
// task that doesn't build for anyone else.
func (r Repo) Untracked() []string {
	out, err := r.run("", "status") // not read(): untracked paths need a snapshot
	if err != nil {
		return nil
	}
	var paths []string
	in := false
	for _, l := range strings.Split(out, "\n") {
		switch {
		case strings.HasPrefix(l, "Untracked paths:"):
			in = true
		case in && strings.HasPrefix(l, "? "):
			paths = append(paths, strings.TrimPrefix(l, "? "))
		default:
			in = false
		}
	}
	return paths
}

// VerifyReport is a verify run, reduced to what's worth keeping in context.
type VerifyReport struct {
	Command string `json:"command"`
	OK      bool   `json:"ok"`
	Exit    int    `json:"exit"`
	Log     string `json:"log"`
	Tail    string `json:"tail,omitempty"`
	Seconds int    `json:"seconds"`
}

// Verify runs jt.verify at the workspace root. Output goes to a log file with only
// the tail reported on failure: raw build output sitting in an agent's context is
// the most expensive thing it can do, and "exit code is truth" needs no output.
func (r Repo) Verify() (*VerifyReport, error) {
	command := r.Config("jt.verify")
	if command == "" {
		return nil, errors.New("no verify command configured (`jt verify --set <cmd>`)")
	}
	root, err := r.Root()
	if err != nil {
		return nil, err
	}
	dir := StateDir("verify")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	path := filepath.Join(dir, time.Now().Format("20060102-150405.000")+".log")
	f, err := os.Create(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	cmd := exec.Command("sh", "-c", command)
	cmd.Dir = root
	cmd.Stdout, cmd.Stderr = f, f
	start := time.Now()
	runErr := cmd.Run()
	rep := &VerifyReport{Command: command, OK: runErr == nil, Log: path, Seconds: int(time.Since(start).Seconds())}
	if runErr != nil {
		var ee *exec.ExitError
		if !errors.As(runErr, &ee) {
			return nil, runErr
		}
		rep.Exit = ee.ExitCode()
		rep.Tail = tailFile(path, 30)
	}
	pruneLogs(dir, 50)
	return rep, nil
}

// pruneLogs keeps the newest n files; names sort by time.
func pruneLogs(dir string, n int) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for i := 0; i < len(entries)-n; i++ {
		os.Remove(filepath.Join(dir, entries[i].Name()))
	}
}

func tailFile(path string, n int) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}

// Strip removes jt's trailers, optionally rewriting the message in one operation.
func (r Repo) Strip(q, message string) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	m := t.Msg
	if message != "" {
		m.SetAbove(message)
	}
	m.Strip()
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return &Result{Task: t, Note: "stripped — off the board for good"}, nil
}

// Block parks a question on a task.
func (r Repo) Block(q, question string, options []string, recommend int) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	if recommend > len(options) {
		return nil, fmt.Errorf("--recommend %d, but only %d options", recommend, len(options))
	}
	m := t.Msg
	if !blank(question) {
		m.appendSection(FormatFork(question, options, recommend))
	}
	m.Set(KeyStatus, "blocked")
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "blocked")
}

// Defer shelves a task: never ready, never raised again until revived.
func (r Repo) Defer(q, reason string) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	m := t.Msg
	if !blank(reason) {
		m.appendSection("DEFERRED: " + strings.TrimSpace(reason))
	}
	m.Set(KeyStatus, "deferred")
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "deferred")
}

// DecideOpts records an answer to a parked fork.
type DecideOpts struct {
	Text   string // free-form decision
	Option string // or an option key from the fork
	Moot   bool   // the answer makes the task moot: mark it done
}

// Decide replaces the open question with its resolution and unblocks the task, as
// one operation, so a decided task can't be left blocked or a question left stale.
func (r Repo) Decide(q string, o DecideOpts) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	if t.Status != "blocked" && t.Status != "deferred" {
		return nil, fmt.Errorf("%s is %s, not blocked", t.ID, t.Status)
	}
	m := t.Msg
	text := strings.TrimSpace(o.Text)
	if o.Option != "" {
		f := m.ParseFork()
		if f == nil {
			return nil, fmt.Errorf("%s has no recorded options", t.ID)
		}
		i := slices.IndexFunc(f.Options, func(x Option) bool { return strings.EqualFold(x.Key, o.Option) })
		if i < 0 {
			return nil, fmt.Errorf("%s has no option %q", t.ID, o.Option)
		}
		if text == "" {
			text = f.Options[i].Text
		} else {
			text = f.Options[i].Text + " — " + text
		}
	}
	if text == "" {
		return nil, errors.New("a decision needs text or --option")
	}
	m.removeBlocked()
	m.appendSection(fmt.Sprintf("DECIDED %s: %s", today(), text))
	status := "todo"
	if o.Moot {
		status = "done"
	}
	m.Set(KeyStatus, status)
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "decided → "+status)
}

// Reopen sends a task back to todo, with why: the rejection path for `testing`.
func (r Repo) Reopen(q, reason string) (*Result, error) {
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	m := t.Msg
	if !blank(reason) {
		m.appendSection(fmt.Sprintf("REOPENED %s: %s", today(), strings.TrimSpace(reason)))
	}
	m.Set(KeyStatus, "todo")
	if err := r.describe(t.ID, m); err != nil {
		return nil, err
	}
	return r.result(t.ID, "reopened")
}

// SetNeeds rewires blocker edges: a task's parents become these blockers (plus,
// unless replace is set, its existing unfinished ones). With nothing left it goes
// back on the work tip.
func (r Repo) SetNeeds(q string, blockers []string, replace bool) (*Result, error) {
	b, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	var dest []string
	if !replace {
		dest = t.NeedsList()
	}
	for _, s := range blockers {
		bt, err := b.Resolve(s)
		if err != nil {
			return nil, err
		}
		if bt.ID == t.ID {
			return nil, fmt.Errorf("%s can't block itself", t.ID)
		}
		if !slices.Contains(dest, bt.ID) {
			dest = append(dest, bt.ID)
		}
	}
	if len(dest) == 0 {
		tip, err := r.Tip("")
		if err != nil {
			return nil, err
		}
		dest = []string{tip}
	}
	args := []string{"rebase", "-s", t.ID, "--quiet"}
	for _, d := range dest {
		args = append(args, "-o", d)
	}
	if _, err := r.run("", args...); err != nil {
		return nil, err
	}
	return r.result(t.ID, "needs updated")
}

// Reaped says what happened to one abandoned claim.
type Reaped struct {
	ID     string `json:"id"`
	Action string `json:"action"` // reset | escalated
}

// MaxReclaims is how many times a claim may be abandoned before a person looks.
const MaxReclaims = 1

// Reap recovers abandoned claims — a task left `doing` isn't ready, so it silently
// drops out of the pool and a run can end declaring victory with work half-done.
// First leak: back to todo. Second leak of the same task: blocked, because a third
// worker won't fix whatever is wrong. The count is a trailer so it survives across
// sessions and rounds instead of living in one loop's memory.
//
// With no ids it reaps tasks no workspace is on; here also includes this
// workspace's @, for callers that know no worker is live in it. Tasks that are
// another workspace's @ are left alone: that's somebody's live worker.
func (r Repo) Reap(ids []string, here bool) ([]Reaped, error) {
	b, err := r.Load()
	if err != nil {
		return nil, err
	}
	var targets []*Task
	if len(ids) > 0 {
		for _, q := range ids {
			t, err := b.Resolve(q)
			if err != nil {
				return nil, err
			}
			if t.Status != "doing" {
				return nil, fmt.Errorf("%s is %s, not doing", t.ID, t.Status)
			}
			targets = append(targets, t)
		}
	} else {
		for _, t := range b.Tasks {
			if t.Status != "doing" {
				continue
			}
			mine := t.Current && len(t.Workspaces) == 1
			if t.Orphaned || (here && mine) {
				targets = append(targets, t)
			}
		}
	}
	var out []Reaped
	for _, t := range targets {
		m := t.Msg
		n, _ := strconv.Atoi(m.Get(KeyReclaims))
		action := "reset"
		if n >= MaxReclaims {
			action = "escalated"
			m.appendSection(FormatFork(fmt.Sprintf("Workers left this `doing` %d times without closing it out. Retry, split it, or drop it?", n+1), nil, 0))
			m.Set(KeyStatus, "blocked")
		} else {
			m.Set(KeyStatus, "todo")
		}
		m.Set(KeyReclaims, strconv.Itoa(n+1))
		if err := r.describe(t.ID, m); err != nil {
			return out, err
		}
		out = append(out, Reaped{t.ID, action})
	}
	return out, nil
}

// Land moves a finished task from a parallel lane into the target workspace's
// line. Rebasing onto its tip isn't enough: the task wouldn't be an ancestor of
// that @, so the tip wouldn't advance and each landing would just be another
// sibling. Inserting before @ makes it part of the line.
//
// Clean here is textual, not semantic — the caller still has to run verify.
func (r Repo) Land(q, into string, force bool) (*Result, error) {
	if into == "" {
		into = "default"
	}
	_, t, err := r.resolve(q)
	if err != nil {
		return nil, err
	}
	if !force && !finished(t.Status) {
		return nil, fmt.Errorf("%s is %s; only finished work lands", t.ID, t.Status)
	}
	target := into + "@"
	if t.Needs != "" {
		return nil, fmt.Errorf("%s needs %s, which hasn't landed", t.ID, t.Needs)
	}
	in, err := r.read("log", "-r", fmt.Sprintf("%s & ::%s", t.ID, target), "--no-graph", "-T", `"x"`)
	if err != nil {
		return nil, err
	}
	if in != "" {
		return r.result(t.ID, "already in "+into+"'s line")
	}
	if _, err := r.run("", "rebase", "-r", t.ID, "--insert-before", target, "--quiet"); err != nil {
		return nil, err
	}
	res, err := r.result(t.ID, "landed in "+into+"'s line; run verify, a clean rebase isn't proof")
	if err == nil && res.Task != nil && res.Task.Conflict {
		return res, fmt.Errorf("%s conflicts after landing", t.ID)
	}
	return res, err
}

// Unlanded lists finished tasks not yet in a workspace's line, parents first.
func (r Repo) Unlanded(into string) ([]string, error) {
	if into == "" {
		into = "default"
	}
	out, err := r.read("log", "-r", fmt.Sprintf("(%s) ~ ::%s@", TasksRevset, into), "--no-graph", "--reversed", "-T", `change_id.shortest(8) ++ "\n"`)
	if err != nil {
		return nil, err
	}
	b, err := r.Load()
	if err != nil {
		return nil, err
	}
	var ids []string
	for _, id := range strings.Fields(out) {
		if t := b.ByID[id]; t != nil && finished(t.Status) {
			ids = append(ids, id)
		}
	}
	return ids, nil
}

// Lane returns the path of a named workspace for parallel or isolated workers,
// creating it next to the repo if needed and running jt.setup in it once (a fresh
// workspace has no installed dependencies, so it can't run verify without that).
func (r Repo) Lane(name string) (path string, created bool, err error) {
	if out, e := r.read("workspace", "root", "--name", name); e == nil {
		return strings.TrimSpace(out), false, nil
	}
	root, err := r.Root()
	if err != nil {
		return "", false, err
	}
	path = filepath.Join(filepath.Dir(root), filepath.Base(root)+"-"+name)
	if _, err := r.run("", "workspace", "add", "--quiet", "--name", name, path); err != nil {
		return "", false, err
	}
	if setup := r.Config("jt.setup"); setup != "" {
		cmd := exec.Command("sh", "-c", setup)
		cmd.Dir = path
		if out, err := cmd.CombinedOutput(); err != nil {
			return path, true, fmt.Errorf("jt.setup failed in %s: %w\n%s", path, err, out)
		}
	}
	return path, true, nil
}

// EvoEntry is one description change in a task's history.
type EvoEntry struct {
	Commit, Time string
	Empty        bool
	First        bool
	Text         string   // the full description, first entry only
	Changes      []string // trailer transitions, checklist progress, body deltas
}

// Change prefixes, so renderers can colour without re-parsing.
const (
	ChangeMeta = "~ "
	ChangeAdd  = "+ "
	ChangeDel  = "- "
)

// Evo builds a task's trail, collapsing rewrites that didn't touch the
// description (rebases, snapshots) so what's left is what actually changed.
func (r Repo) Evo(rev string) ([]EvoEntry, error) {
	const tmpl = `commit.commit_id().short(8) ++ "\t" ++ commit.committer().timestamp().local().format("%Y-%m-%d %H:%M") ++ "\t" ++ if(commit.empty(),"1","0") ++ "\t" ++ json(commit.description()) ++ "\n"`
	out, err := r.read("evolog", "-r", rev, "--reversed", "--no-graph", "-T", tmpl)
	if err != nil {
		return nil, err
	}
	type row struct {
		commit, ts string
		empty      bool
		desc       string
	}
	var rows []row
	for _, l := range strings.Split(out, "\n") {
		p := strings.SplitN(l, "\t", 4)
		if len(p) < 4 {
			continue
		}
		var d string
		if err := json.Unmarshal([]byte(p[3]), &d); err != nil {
			return nil, fmt.Errorf("parsing evolog: %w", err)
		}
		cur := row{p[0], p[1], p[2] == "1", d}
		if n := len(rows); n > 0 && strings.TrimRight(rows[n-1].desc, " \t\n") == strings.TrimRight(d, " \t\n") {
			rows[n-1].commit, rows[n-1].ts, rows[n-1].empty = cur.commit, cur.ts, cur.empty
			continue
		}
		rows = append(rows, cur)
	}
	var entries []EvoEntry
	for i, cur := range rows {
		e := EvoEntry{Commit: cur.commit, Time: cur.ts, Empty: cur.empty, First: i == 0}
		if i == 0 {
			e.Text = strings.TrimRight(cur.desc, "\n")
		} else {
			e.Changes = diffMessages(ParseMessage(rows[i-1].desc), ParseMessage(cur.desc))
		}
		entries = append(entries, e)
	}
	return entries, nil
}

func diffMessages(a, b Message) []string {
	var out []string
	for _, t := range b.Trailers {
		switch old := a.Get(t.Key); {
		case old == "":
			out = append(out, ChangeMeta+"+ "+t.Key+": "+t.Value)
		case old != t.Value && b.Get(t.Key) == t.Value:
			out = append(out, fmt.Sprintf("%s%s: %s → %s", ChangeMeta, t.Key, old, t.Value))
		}
	}
	for _, t := range a.Trailers {
		if b.Get(t.Key) == "" {
			out = append(out, ChangeMeta+"- "+t.Key+" (dropped)")
		}
	}
	ab, bb := a.Above(), b.Above()
	ad, at := Checklist(ab)
	bd, bt := Checklist(bb)
	if ad != bd || at != bt {
		out = append(out, fmt.Sprintf("%schecklist: %d/%d → %d/%d", ChangeMeta, ad, at, bd, bt))
	}
	// A multiset line delta: order changes aren't what a reader wants from this.
	count := map[string]int{}
	for _, l := range strings.Split(bb, "\n") {
		count[l]++
	}
	for _, l := range strings.Split(ab, "\n") {
		if l == "" {
			continue
		}
		if count[l] > 0 {
			count[l]--
		} else {
			out = append(out, ChangeDel+l)
		}
	}
	count = map[string]int{}
	for _, l := range strings.Split(ab, "\n") {
		count[l]++
	}
	for _, l := range strings.Split(bb, "\n") {
		if l == "" {
			continue
		}
		if count[l] > 0 {
			count[l]--
		} else {
			out = append(out, ChangeAdd+l)
		}
	}
	return out
}

// DiffStat is `jj diff --stat` for a revision.
func (r Repo) DiffStat(rev string) string {
	out, err := r.read("diff", "-r", rev, "--stat")
	if err != nil {
		return ""
	}
	return strings.TrimRight(out, "\n")
}

// Graph renders the task DAG with jj's own graph drawing. Including the tasks'
// parents connects them into one component: jj draws a trailing "~" per
// disconnected component, so without it you get one per task.
func (r Repo) Graph(template string, color bool) (string, error) {
	mode := "--color=never"
	if color {
		mode = "--color=always"
	}
	cmd := exec.Command("jj", "log", mode, "--ignore-working-copy", "-r", GraphRevset(),
		"--config", "ui.log-synthetic-elided-nodes=false", "-T", template)
	cmd.Dir = r.Dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", errors.New(strings.TrimSpace(string(out)))
	}
	return string(out), nil
}

// GraphRevset is what the graph views show.
func GraphRevset() string {
	return fmt.Sprintf("(%s) | @ | parents(%s)", TasksRevset, TasksRevset)
}
