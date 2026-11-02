package core

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseMessage(t *testing.T) {
	cases := []struct {
		name, in, subject, detail string
		status                    string
		trailers                  int
	}{
		{"plain", "sum\n\nbody\n\nTask-Status: todo\nPriority: P1\n", "sum", "body", "todo", 2},
		{"mention in body is not a status", "sum\n\nTask-Status: done is what we set\nnot a trailer\n", "sum", "Task-Status: done is what we set\nnot a trailer", "", 0},
		{"subject is never a trailer block", "Fix: the thing\n", "Fix: the thing", "", "", 0},
		{"mixed last paragraph is prose", "sum\n\nnote\nTask-Status: done\n", "sum", "note\nTask-Status: done", "", 0},
		{"empty", "", "", "", "", 0},
	}
	for _, c := range cases {
		m := ParseMessage(c.in)
		if m.Subject != c.subject || m.Detail != c.detail || m.Get(KeyStatus) != c.status || len(m.Trailers) != c.trailers {
			t.Errorf("%s: got %+v", c.name, m)
		}
	}
}

func TestForeignTrailersSurvive(t *testing.T) {
	m := ParseMessage("s\n\nCo-Authored-By: a\nCo-Authored-By: b\nTask-Status: todo\nPriority: P1\n")
	m.Set(KeyStatus, "done")
	m.Strip()
	want := "s\n\nCo-Authored-By: a\nCo-Authored-By: b\n"
	if m.String() != want {
		t.Errorf("got %q want %q", m.String(), want)
	}
}

func TestSetBodyKeepsSubject(t *testing.T) {
	m := ParseMessage("title\n\nold\n\nTask-Status: todo\n")
	m.SetBody("new")
	if m.Subject != "title" || m.Detail != "new" {
		t.Errorf("%+v", m)
	}
	m.SetBody("title\n\nfed back whole")
	if m.Subject != "title" || m.Detail != "fed back whole" {
		t.Errorf("duplicate subject not dropped: %+v", m)
	}
}

func TestForkRoundTrip(t *testing.T) {
	m := ParseMessage("t\n\nintro\n\nTask-Status: blocked\n")
	m.appendSection(FormatFork("Which store?", []string{"sqlite", "flat files"}, 2))
	f := ParseMessage(m.String()).ParseFork()
	if f == nil || f.Question != "Which store?" || len(f.Options) != 2 {
		t.Fatalf("%+v", f)
	}
	if f.Options[0].Key != "a" || f.Options[1].Text != "flat files" || !f.Options[1].Recommended || f.Options[0].Recommended {
		t.Errorf("%+v", f.Options)
	}
	m.removeBlocked()
	if m.Detail != "intro" {
		t.Errorf("detail %q", m.Detail)
	}
}

func TestForkFreeformMultiParagraph(t *testing.T) {
	m := ParseMessage("t\n\nBLOCKED: first para\n\nsecond para\n\nTask-Status: blocked\n")
	if f := m.ParseFork(); f == nil || !strings.Contains(f.Question, "second para") {
		t.Errorf("%+v", f)
	}
	m.removeBlocked()
	if m.Detail != "" {
		t.Errorf("left %q", m.Detail)
	}
}

func TestScopesOverlap(t *testing.T) {
	yes := [][2]string{{"src/a", "src/a"}, {"src", "src/a.go"}, {"src/", "./src/b"}, {"x, src/*.go", "src/b.go"}, {".", "anything"}}
	no := [][2]string{{"src/a", "src/ab"}, {"", "src"}, {"a", "b, c"}}
	for _, c := range yes {
		if !ScopesOverlap(c[0], c[1]) {
			t.Errorf("want overlap %v", c)
		}
	}
	for _, c := range no {
		if ScopesOverlap(c[0], c[1]) {
			t.Errorf("want no overlap %v", c)
		}
	}
}

// ---- integration: real jj in a scratch repo, with hermetic config.

func repo(t *testing.T) Repo {
	t.Helper()
	if _, err := exec.LookPath("jj"); err != nil {
		t.Skip("jj not installed")
	}
	dir := t.TempDir()
	cfg := filepath.Join(dir, "jj.toml")
	os.WriteFile(cfg, []byte("[user]\nname='t'\nemail='t@t'\n[ui]\nconflict-marker-style='git'\n"), 0o644)
	t.Setenv("JJ_CONFIG", cfg)
	t.Setenv("XDG_STATE_HOME", filepath.Join(dir, "state"))
	root := filepath.Join(dir, "r")
	os.Mkdir(root, 0o755)
	r := Repo{Dir: root}
	if _, err := r.run("", "git", "init", "--quiet", "."); err != nil {
		t.Fatal(err)
	}
	write(t, r, "base.txt", "base\n")
	mustRun(t, r, "describe", "--quiet", "-m", "base")
	mustRun(t, r, "new", "--quiet")
	return r
}

func write(t *testing.T, r Repo, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(r.Dir, name), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func mustRun(t *testing.T, r Repo, args ...string) string {
	t.Helper()
	out, err := r.run("", args...)
	if err != nil {
		t.Fatalf("jj %v: %v", args, err)
	}
	return out
}

func newTask(t *testing.T, r Repo, o NewOpts) string {
	t.Helper()
	res, err := r.New(o)
	if err != nil {
		t.Fatal(err)
	}
	return res.Task.ID
}

func load(t *testing.T, r Repo) *Board {
	t.Helper()
	b, err := r.Load()
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func parentsOf(t *testing.T, r Repo, id string) string {
	t.Helper()
	return strings.TrimSpace(mustRun(t, r, "log", "-r", id, "--no-graph", "--ignore-working-copy", "-T", `parents.map(|p| p.description().first_line()).join(",")`))
}

// Regression: done commits weren't tips, so a run never formed a line.
func TestRunAccumulatesAsALine(t *testing.T) {
	r := repo(t)
	a := newTask(t, r, NewOpts{Summary: "A"})
	b := newTask(t, r, NewOpts{Summary: "B"})
	if _, err := r.Start(a, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	write(t, r, "a.txt", "a\n")
	// Regression: `done` right after an edit used to see a stale `empty`.
	res, err := r.Done(a)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Warnings) != 0 {
		t.Errorf("false warning: %v", res.Warnings)
	}
	if _, err := r.Start(b, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	if got := parentsOf(t, r, b); got != "A" {
		t.Errorf("B built on %q, want A", got)
	}
}

// Regression: starting a blocker rebased it away from its dependents.
func TestStartBlockerKeepsDependentEdge(t *testing.T) {
	r := repo(t)
	x := newTask(t, r, NewOpts{Summary: "X"})
	y := newTask(t, r, NewOpts{Summary: "Y", Blockers: []string{x}})
	// Move the tip so that starting X really has to rebase.
	mustRun(t, r, "new", "--quiet", "-m", "more work")
	write(t, r, "more.txt", "m\n")
	mustRun(t, r, "new", "--quiet")
	if _, err := r.Start(x, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	if got := parentsOf(t, r, x); got != "more work" {
		t.Errorf("X on %q", got)
	}
	if got := load(t, r).ByID[y].Needs; got != x {
		t.Errorf("Y needs %q, want %q", got, x)
	}
}

func TestStartGates(t *testing.T) {
	r := repo(t)
	x := newTask(t, r, NewOpts{Summary: "X"})
	y := newTask(t, r, NewOpts{Summary: "Y", Blockers: []string{x}})
	if _, err := r.Start(y, StartOpts{}); err == nil || !strings.Contains(err.Error(), "needs") {
		t.Errorf("started with unfinished blocker: %v", err)
	}
	d := newTask(t, r, NewOpts{Summary: "D"})
	if _, err := r.Defer(d, "later"); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Start(d, StartOpts{}); err == nil {
		t.Error("started a deferred task")
	}
	if _, err := r.Start(x, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	if res, err := r.Start(x, StartOpts{}); err != nil || res.Note != "already yours" {
		t.Errorf("restart not idempotent: %v %v", res, err)
	}
}

func TestClaimedElsewhereAndStaleLane(t *testing.T) {
	r := repo(t)
	x := newTask(t, r, NewOpts{Summary: "X"})
	path, created, err := r.Lane("w1")
	if err != nil || !created {
		t.Fatal(err, created)
	}
	if again, created, _ := r.Lane("w1"); again != path || created {
		t.Errorf("Lane not idempotent: %s %v", again, created)
	}
	lane := Repo{Dir: path}
	// A worker that lost its cwd must not seize the default workspace's @.
	if _, err := r.Start(x, StartOpts{In: "w1", Force: true}); err == nil || !strings.Contains(err.Error(), "not workspace w1") {
		t.Errorf("--in not enforced: %v", err)
	}
	if st := load(t, r).ByID[x].Status; st != "todo" {
		t.Errorf("refused start still wrote: %s", st)
	}
	if _, err := lane.Start(x, StartOpts{In: "w1"}); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Start(x, StartOpts{}); err == nil || !strings.Contains(err.Error(), "w1") {
		t.Errorf("seized a claimed task: %v", err)
	}
	// Default rewrites the lane's @, leaving the lane stale; its next op recovers.
	if _, err := r.Set(x, [][2]string{{"priority", "P1"}}); err != nil {
		t.Fatal(err)
	}
	if _, err := lane.Set(x, [][2]string{{"scope", "s"}}); err != nil {
		t.Errorf("stale workspace not recovered: %v", err)
	}
	// A task on another workspace's @ is live: never reaped.
	if got, err := r.Reap(nil, true); err != nil || len(got) != 0 {
		t.Errorf("reaped a live claim: %v %v", got, err)
	}
}

func TestFinishGates(t *testing.T) {
	r := repo(t)
	mustRun(t, r, "config", "set", "--repo", "snapshot.auto-track", "none()")
	x := newTask(t, r, NewOpts{Summary: "X"})
	if _, err := r.Start(x, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Finish(x, FinishOpts{}); err == nil || !strings.Contains(err.Error(), "no code") {
		t.Errorf("finished an empty task: %v", err)
	}
	write(t, r, "tracked.txt", "1\n")
	write(t, r, "forgot.txt", "1\n")
	mustRun(t, r, "file", "track", "tracked.txt")
	if err := r.SetConfig("jt.verify", "echo boom; exit 7"); err != nil {
		t.Fatal(err)
	}
	_, err := r.Finish(x, FinishOpts{Message: "clean"})
	vf, ok := err.(*VerifyFailed)
	if !ok || vf.Report.Exit != 7 || !strings.Contains(vf.Report.Tail, "boom") {
		t.Fatalf("verify gate: %v", err)
	}
	tk := load(t, r).ByID[x]
	if tk.Status != "doing" || tk.Summary != "X" {
		t.Errorf("failed finish wrote something: %+v", tk)
	}
	r.SetConfig("jt.verify", "true")
	res, err := r.Finish(x, FinishOpts{Message: "clean\n\nwhy", Testing: "look at it"})
	if err != nil {
		t.Fatal(err)
	}
	tk = res.Task
	if tk.Status != "testing" || tk.Summary != "clean" || !strings.Contains(tk.Msg.Detail, "TESTING: look at it") {
		t.Errorf("%+v", tk)
	}
	if len(res.Warnings) != 1 || !strings.Contains(res.Warnings[0], "forgot.txt") {
		t.Errorf("untracked warning: %v", res.Warnings)
	}
}

func TestDecide(t *testing.T) {
	r := repo(t)
	x := newTask(t, r, NewOpts{Summary: "X", Body: "ctx"})
	if _, err := r.Block(x, "Which?", []string{"one", "two"}, 1); err != nil {
		t.Fatal(err)
	}
	f := load(t, r).ByID[x].Msg.ParseFork()
	if f == nil || !f.Options[0].Recommended {
		t.Fatalf("%+v", f)
	}
	if _, err := r.Start(x, StartOpts{}); err == nil {
		t.Error("started blocked")
	}
	res, err := r.Decide(x, DecideOpts{Option: "b", Text: "because"})
	if err != nil {
		t.Fatal(err)
	}
	if res.Task.Status != "todo" || strings.Contains(res.Task.Msg.Detail, "BLOCKED") || !strings.Contains(res.Task.Msg.Detail, "two — because") || !strings.HasPrefix(res.Task.Msg.Detail, "ctx") {
		t.Errorf("%+v", res.Task)
	}
	if _, err := r.Decide(x, DecideOpts{Text: "again"}); err == nil {
		t.Error("decided a non-blocked task")
	}
}

func TestReapEscalates(t *testing.T) {
	r := repo(t)
	x := newTask(t, r, NewOpts{Summary: "X"})
	r.Start(x, StartOpts{})
	got, err := r.Reap(nil, true)
	if err != nil || len(got) != 1 || got[0].Action != "reset" {
		t.Fatal(got, err)
	}
	r.Start(x, StartOpts{})
	got, err = r.Reap(nil, true)
	if err != nil || len(got) != 1 || got[0].Action != "escalated" {
		t.Fatal(got, err)
	}
	tk := load(t, r).ByID[x]
	if tk.Status != "blocked" || tk.Msg.ParseFork() == nil {
		t.Errorf("%+v", tk)
	}
	r.Strip(x, "")
	desc := mustRun(t, r, "log", "-r", x, "--no-graph", "--ignore-working-copy", "-T", "description")
	if strings.Contains(desc, "Task-") {
		t.Errorf("strip left managed trailers: %q", desc)
	}
}

// The old instruction (rebase onto the default tip) never converged: landed tasks
// weren't ancestors of default@, so the tip stood still and each was a sibling.
func TestLandConverges(t *testing.T) {
	r := repo(t)
	var ids []string
	for i, name := range []string{"one", "two"} {
		id := newTask(t, r, NewOpts{Summary: name})
		lp, _, err := r.Lane("w" + name)
		if err != nil {
			t.Fatal(err)
		}
		lane := Repo{Dir: lp}
		if _, err := lane.Start(id, StartOpts{}); err != nil {
			t.Fatal(err)
		}
		write(t, lane, name+".txt", "x\n")
		if _, err := lane.Finish(id, FinishOpts{NoVerify: true}); err != nil {
			t.Fatalf("%d: %v", i, err)
		}
		ids = append(ids, id)
	}
	if got, err := r.Unlanded(""); err != nil || len(got) != 2 {
		t.Errorf("unlanded %v %v", got, err)
	}
	for _, id := range ids {
		if _, err := r.Land(id, "", false); err != nil {
			t.Fatal(err)
		}
	}
	tip, err := r.Tip("")
	if err != nil {
		t.Fatal(err)
	}
	if tip != ids[1] {
		t.Errorf("tip %s, want last landed %s", tip, ids[1])
	}
	if got := parentsOf(t, r, ids[1]); got != "one" {
		t.Errorf("two on %q", got)
	}
	if _, err := r.Land(ids[0], "", false); err != nil {
		t.Errorf("re-land not idempotent: %v", err)
	}
	if got, _ := r.Unlanded(""); len(got) != 0 {
		t.Errorf("still unlanded: %v", got)
	}
}

func TestNextAndCheck(t *testing.T) {
	r := repo(t)
	doing := newTask(t, r, NewOpts{Summary: "in flight", Scope: "src/core"})
	low := newTask(t, r, NewOpts{Summary: "low", Priority: "P3", Scope: "docs"})
	coll := newTask(t, r, NewOpts{Summary: "collides", Priority: "P0", Scope: "src/core/x.go"})
	high := newTask(t, r, NewOpts{Summary: "high", Priority: "P1", Scope: "docs/y"})
	if _, err := r.Start(doing, StartOpts{}); err != nil {
		t.Fatal(err)
	}
	b := load(t, r)
	picks, skipped := b.Next(NextOpts{})
	if len(picks) != 2 || picks[0].ID != high || picks[1].ID != low {
		t.Errorf("picks %v", picks)
	}
	if len(skipped) != 1 || skipped[0].ID != coll {
		t.Errorf("skipped %v", skipped)
	}
	if picks, _ := b.Next(NextOpts{Disjoint: true}); len(picks) != 1 {
		t.Errorf("disjoint: %d", len(picks))
	}
	if picks, _ := b.Next(NextOpts{Limit: 1}); len(picks) != 1 {
		t.Errorf("limit: %d", len(picks))
	}
	if picks, _ := b.Next(NextOpts{Focus: "LOW"}); len(picks) != 1 || picks[0].ID != low {
		t.Errorf("focus: %v", picks)
	}
	// Leave `doing` behind by moving @ away: it becomes an orphan.
	mustRun(t, r, "new", "--quiet", "root()")
	ps := load(t, r).Check()
	if !HasErrors(ps) {
		t.Errorf("orphan not flagged: %+v", ps)
	}
}

func TestFocusIgnoresIDSubstrings(t *testing.T) {
	task := &Task{ID: "xlowyzkm", FullID: "xlowyzkmqqqq", Summary: "unrelated"}
	if focusMatches(task, []string{"low"}) {
		t.Error("matched inside a random id")
	}
	if !focusMatches(task, []string{"xlow"}) || !focusMatches(task, []string{"unrel"}) {
		t.Error("should match an id prefix and summary text")
	}
}

func TestBodyMentionIsNotATask(t *testing.T) {
	r := repo(t)
	mustRun(t, r, "new", "--quiet", "-m", "docs\n\nwe set\nTask-Status: done\nin prose")
	if n := len(load(t, r).Tasks); n != 0 {
		t.Errorf("misfiled %d", n)
	}
}

func TestResolve(t *testing.T) {
	r := repo(t)
	a := newTask(t, r, NewOpts{Summary: "fix the auth flow"})
	newTask(t, r, NewOpts{Summary: "fix the build"})
	b := load(t, r)
	if tk, err := b.Resolve("AUTH"); err != nil || tk.ID != a {
		t.Errorf("%v %v", tk, err)
	}
	if _, err := b.Resolve("fix"); err == nil || !strings.Contains(err.Error(), "ambiguous") {
		t.Errorf("%v", err)
	}
	if _, err := b.Resolve(".*"); err == nil {
		t.Error("query treated as a pattern")
	}
	if tk, err := b.Resolve(b.ByID[a].FullID); err != nil || tk.ID != a {
		t.Errorf("full id: %v %v", tk, err)
	}
}
