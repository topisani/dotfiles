package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"os"
	"os/exec"
	"slices"
	"strings"

	"github.com/charmbracelet/x/term"
	"github.com/spf13/cobra"

	"jt/internal/core"
	"jt/internal/tui"
)

var (
	repo    core.Repo
	jsonOut bool
)

func isTTY(f *os.File) bool { return term.IsTerminal(f.Fd()) }

func interactive() bool { return isTTY(os.Stdin) && isTTY(os.Stdout) }

const helpText = `jt is a task tracker on jj changes. A task is a change with a Task-Status: trailer;
the change id is the task id and blockers are parent edges.

<id> may be a change-id prefix or words matching a summary.

Statuses: todo ready doing investigating blocked testing deferred done
  testing   implementation finished, waiting on a person; counts as finished
  done      confirmed but not cleaned up; "jt strip" takes it off the graph for good
  deferred  shelved: never ready, never raised again until revived

Bare "jt" opens the TUI in a terminal and prints the board otherwise.`

func rootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:           "jt",
		Short:         "task tracker on jj changes",
		Long:          helpText,
		SilenceUsage:  true,
		SilenceErrors: true,
		Args:          cobra.NoArgs,
		RunE: func(c *cobra.Command, _ []string) error {
			if interactive() {
				return tui.Run(repo, tui.ScreenBoard, assetTemplate())
			}
			return runList(false, false, nil)
		},
		PersistentPreRunE: func(c *cobra.Command, _ []string) error {
			if c.Annotations["norepo"] == "1" {
				return nil
			}
			for p := c; p != nil; p = p.Parent() {
				if p.Name() == "completion" || p.Name() == "help" || p.Name() == cobra.ShellCompRequestCmd {
					return nil
				}
			}
			if !repo.IsRepo() {
				return errors.New("not in a jj repo")
			}
			return nil
		},
	}
	root.PersistentFlags().BoolVar(&jsonOut, "json", false, "machine-readable result on stdout")
	root.AddGroup(&cobra.Group{ID: "view", Title: "Viewing:"}, &cobra.Group{ID: "work", Title: "Working a task:"},
		&cobra.Group{ID: "manage", Title: "Managing tasks:"}, &cobra.Group{ID: "run", Title: "Running agents:"})
	root.SetHelpCommandGroupID("view")
	root.SetCompletionCommandGroupID("run")
	for _, c := range []*cobra.Command{
		tuiCmd(), listCmd(), jsonCmd(), statusCmd(), showCmd(), evoCmd(), tipCmd(), uiCmd(),
		startCmd(), finishCmd(), doneCmd(), blockCmd(), verifyCmd(),
		newCmd(), setCmd(), needsCmd(), deferCmd(), decideCmd(), reopenCmd(), stripCmd(),
		nextCmd(), briefCmd(), checkCmd(), reapCmd(), laneCmd(), landCmd(), grindCmd(), installCmd(),
	} {
		root.AddCommand(c)
	}
	return root
}

func group(id string, c *cobra.Command) *cobra.Command {
	c.GroupID = id
	return c
}

// ---------------------------------------------------------------- output

func style(code, s string) string {
	if !isTTY(os.Stdout) || os.Getenv("NO_COLOR") != "" {
		return s
	}
	return "\x1b[" + code + "m" + s + "\x1b[0m"
}

func statusCode(s string) string {
	switch s {
	case "doing":
		return "32"
	case "blocked":
		return "31"
	case "done":
		return "90"
	case "investigating":
		return "35"
	case "testing":
		return "93"
	case "deferred":
		return "37"
	}
	return "34"
}

func taskLine(t *core.Task) string {
	var b strings.Builder
	b.WriteString(style("33", t.ID) + " " + style(statusCode(t.Status), "["+t.Status+"]"))
	if t.Priority != "" {
		b.WriteString(" " + style("35", "("+t.Priority+")"))
	}
	if t.Status == "done" {
		b.WriteString(" " + style("90", t.Summary))
	} else {
		b.WriteString(" " + t.Summary)
	}
	if t.Needs != "" {
		b.WriteString(" " + style("36", "(needs "+t.Needs+")"))
	}
	if t.Conflict {
		b.WriteString(" " + style("31", "(conflict)"))
	}
	if t.Orphaned {
		b.WriteString(" " + style("31", "(orphaned)"))
	} else if len(t.Workspaces) > 0 && t.Status == "doing" {
		b.WriteString(" " + style("36", "("+strings.Join(t.Workspaces, " ")+"@)"))
	}
	if len(t.Collides) > 0 {
		b.WriteString(" " + style("36", "(collides "+strings.Join(t.Collides, " ")+")"))
	}
	return b.String()
}

func printJSON(v any) error {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return err
	}
	_, err := os.Stdout.Write(buf.Bytes())
	return err
}

// report prints a mutation's outcome. Warnings go to stderr so a text caller's
// stdout stays clean, and into the JSON so a --json caller can't miss them.
func report(res *core.Result, err error) error {
	if err != nil {
		return err
	}
	if jsonOut {
		if res.Task != nil {
			t := res.Task.Brief()
			res.Task = &t
		}
		return printJSON(res)
	}
	for _, w := range res.Warnings {
		fmt.Fprintf(os.Stderr, "jt: warning: %s\n", w)
	}
	if res.Task != nil {
		fmt.Printf("jt: %s %s\n", res.Task.ID, res.Note)
	} else {
		fmt.Printf("jt: %s\n", res.Note)
	}
	return nil
}

func printVerify(r *core.VerifyReport) {
	if jsonOut {
		printJSON(r)
		return
	}
	if r.OK {
		fmt.Printf("jt: verify passed (%ds): %s\n", r.Seconds, r.Command)
		return
	}
	fmt.Fprintf(os.Stderr, "jt: verify FAILED, exit %d (%ds): %s\n--- last lines of %s\n%s\n", r.Exit, r.Seconds, r.Command, r.Log, r.Tail)
}

// textValue reads an argument, or stdin when it's "-": stdin is the one way to
// pass multi-line text that no shell quoting can mangle.
func textValue(v string) (string, error) {
	if v != "-" {
		return v, nil
	}
	data, err := io.ReadAll(os.Stdin)
	return string(data), err
}

// ---------------------------------------------------------------- completion

func completeTasks(c *cobra.Command, args []string, _ string) ([]string, cobra.ShellCompDirective) {
	b, err := repo.Load()
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	var out []string
	for _, t := range b.ByPriority(true) {
		out = append(out, t.ID+"\t["+t.Status+"] "+t.Summary)
	}
	return out, cobra.ShellCompDirectiveNoFileComp | cobra.ShellCompDirectiveKeepOrder
}

func firstArgTask(c *cobra.Command, args []string, s string) ([]string, cobra.ShellCompDirective) {
	if len(args) > 0 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	return completeTasks(c, args, s)
}

func fixed(vals ...string) func(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
	return func(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
		return vals, cobra.ShellCompDirectiveNoFileComp
	}
}

// ---------------------------------------------------------------- viewing

func assetTemplate() string { return asset("task_template.jj") }

func tuiCmd() *cobra.Command {
	return group("view", &cobra.Command{
		Use:     "tui",
		Aliases: []string{"t"},
		Short:   "browse and manage the board",
		Args:    cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			return tui.Run(repo, tui.ScreenBoard, assetTemplate())
		},
	})
}

func runList(all, tree bool, statuses []string) error {
	if tree {
		out, err := repo.Graph(assetTemplate(), isTTY(os.Stdout) && os.Getenv("NO_COLOR") == "")
		if err != nil {
			return err
		}
		fmt.Print(out)
		return nil
	}
	b, err := repo.Load()
	if err != nil {
		return err
	}
	shown := 0
	for _, t := range b.ByPriority(all || len(statuses) > 0) {
		if len(statuses) > 0 && !contains(statuses, t.Status) {
			continue
		}
		fmt.Println(taskLine(t))
		shown++
	}
	if shown == 0 {
		fmt.Println("no open tasks")
	}
	return nil
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

func listCmd() *cobra.Command {
	var all, tree bool
	var statuses []string
	c := group("view", &cobra.Command{
		Use:     "list",
		Aliases: []string{"ls", "board"},
		Short:   "print the board, by priority",
		Args:    cobra.NoArgs,
		RunE:    func(*cobra.Command, []string) error { return runList(all, tree, statuses) },
	})
	c.Flags().BoolVarP(&all, "all", "a", false, "include done tasks")
	c.Flags().BoolVarP(&tree, "tree", "t", false, "draw the DAG instead of priority order")
	c.Flags().StringSliceVar(&statuses, "status", nil, "only these statuses")
	c.RegisterFlagCompletionFunc("status", fixed(core.Statuses...))
	return c
}

func jsonCmd() *cobra.Command {
	var all, brief, ready bool
	var statuses []string
	c := group("view", &cobra.Command{
		Use:   "json",
		Short: "the board as JSONL, for scripts and agents",
		Long: `The board as JSONL. -q drops bodies, which are 90% of the output on a real board:
poll with -q and read one body with "jt show <id>" when you need it.`,
		Args: cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			for _, t := range b.Tasks {
				switch {
				case len(statuses) > 0 && !contains(statuses, t.Status):
					continue
				case len(statuses) == 0 && !all && t.Status == "done":
					continue
				case ready && !t.Ready:
					continue
				}
				out := t.Full()
				if brief {
					out = t.Brief()
				}
				if err := printJSON(out); err != nil {
					return err
				}
			}
			return nil
		},
	})
	c.Flags().BoolVarP(&all, "all", "a", false, "include done tasks")
	c.Flags().BoolVarP(&brief, "brief", "q", false, "drop bodies")
	c.Flags().BoolVar(&ready, "ready", false, "only ready tasks")
	c.Flags().StringSliceVar(&statuses, "status", nil, "only these statuses")
	c.RegisterFlagCompletionFunc("status", fixed(core.Statuses...))
	return c
}

func statusCmd() *cobra.Command {
	return group("view", &cobra.Command{
		Use:   "status",
		Short: "the board by lane, with collisions, problems and the next pick",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			picks, _ := b.Next(core.NextOpts{Limit: 1})
			problems := b.Check()
			if jsonOut {
				out := map[string]any{"problems": problems, "workspaces": b.Workspaces}
				lanes := map[string][]core.Task{}
				for _, l := range b.Lanes() {
					for _, t := range l.Tasks {
						lanes[l.Name] = append(lanes[l.Name], t.Brief())
					}
				}
				out["lanes"] = lanes
				if len(picks) > 0 {
					out["next"] = picks[0].ID
				}
				return printJSON(out)
			}
			for _, l := range b.Lanes() {
				if len(l.Tasks) == 0 || l.Name == "Done" {
					continue
				}
				fmt.Printf("%s (%d)\n", style("1", l.Name), len(l.Tasks))
				if l.Name == "Deferred" {
					ids := make([]string, len(l.Tasks))
					for i, t := range l.Tasks {
						ids[i] = t.ID
					}
					fmt.Println("  " + strings.Join(ids, " "))
					continue
				}
				for _, t := range l.Tasks {
					fmt.Println("  " + taskLine(t))
					if f := t.Msg.ParseFork(); f != nil && t.Status == "blocked" {
						fmt.Println("    ? " + strings.ReplaceAll(f.Question, "\n", " "))
					}
				}
			}
			if len(problems) > 0 {
				fmt.Println(style("1", "Problems"))
				for _, p := range problems {
					fmt.Printf("  %s %s %s: %s\n", p.Level, style("33", p.ID), p.Kind, p.Detail)
				}
			}
			fmt.Printf("%s", style("1", "Workspaces"))
			names := slices.Sorted(maps.Keys(b.Workspaces))
			for _, name := range names {
				fmt.Printf(" %s@%s", name, b.Workspaces[name])
			}
			fmt.Println()
			if len(picks) > 0 {
				fmt.Printf("%s %s\n", style("1", "Next"), taskLine(picks[0]))
			}
			return nil
		},
	})
}

func showCmd() *cobra.Command {
	return group("view", &cobra.Command{
		Use:               "show <id>",
		Aliases:           []string{"view"},
		Short:             "a task's full description",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			t, err := b.Resolve(args[0])
			if err != nil {
				return err
			}
			if jsonOut {
				return printJSON(t.Full())
			}
			fmt.Printf("%s\n\n%s", style("33", t.ID), t.Msg.String())
			return nil
		},
	})
}

func evoCmd() *cobra.Command {
	return group("view", &cobra.Command{
		Use:               "evo <id>",
		Aliases:           []string{"taskevo"},
		Short:             "a task's trail: status, priority and checklist changes",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			rev := args[0]
			var title string
			if b, err := repo.Load(); err == nil {
				if t, err := b.Resolve(args[0]); err == nil {
					rev, title = t.ID, t.Summary
				}
			}
			entries, err := repo.Evo(rev) // accepts any revision: a stripped task still has a trail
			if err != nil {
				return fmt.Errorf("no such task or revision '%s'", args[0])
			}
			fmt.Printf("%s %s\n\n", style("33", rev), title)
			for _, e := range entries {
				empty := ""
				if e.Empty {
					empty = "  " + style("90", "(empty)")
				}
				fmt.Printf("  %s  %s%s\n", style("90", e.Time), e.Commit, empty)
				if e.First {
					for _, l := range strings.Split(e.Text, "\n") {
						fmt.Println("      " + l)
					}
				}
				for _, ch := range e.Changes {
					code, text := "0", ch
					switch {
					case strings.HasPrefix(ch, core.ChangeMeta):
						code, text = "35", strings.TrimPrefix(ch, core.ChangeMeta)
					case strings.HasPrefix(ch, core.ChangeAdd):
						code = "32"
					case strings.HasPrefix(ch, core.ChangeDel):
						code = "31"
					}
					fmt.Println("      " + style(code, text))
				}
				fmt.Println()
			}
			if s := repo.DiffStat(rev); s != "" && !strings.HasPrefix(s, "0 files changed") {
				fmt.Println("  " + style("35", "── task diff ──"))
				for _, l := range strings.Split(s, "\n") {
					fmt.Println("  " + l)
				}
			}
			return nil
		},
	})
}

func tipCmd() *cobra.Command {
	var base string
	c := group("view", &cobra.Command{
		Use:   "tip",
		Short: "the current work tip",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			tip, err := repo.Tip(base)
			if err == nil {
				fmt.Println(tip)
			}
			return err
		},
	})
	c.Flags().StringVar(&base, "base", "", "another workspace's tip")
	return c
}

func uiCmd() *cobra.Command {
	return group("view", &cobra.Command{
		Use:                "ui [jjui args]",
		Aliases:            []string{"jjui"},
		Short:              "browse the task graph in jjui",
		DisableFlagParsing: true,
		RunE: func(_ *cobra.Command, args []string) error {
			cmd := exec.Command("jjui", append([]string{"-r", core.GraphRevset()}, args...)...)
			cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
			return cmd.Run()
		},
	})
}

// ---------------------------------------------------------------- working

func startCmd() *cobra.Command {
	var o core.StartOpts
	c := group("work", &cobra.Command{
		Use:   "start <id>",
		Short: "claim a task: rebase onto the work tip, mark doing, make it @",
		Long: `Claim a task: rebase it (and its dependents) onto the work tip, mark it doing,
and make it this workspace's @. Refuses a task with unfinished blockers, or one
that's blocked, deferred, finished, or claimed by another workspace. --force
overrides that. Starting your own task again is a no-op.`,
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.Start(args[0], o))
		},
	})
	c.Flags().BoolVar(&o.Force, "force", false, "skip the claim checks")
	c.Flags().BoolVar(&o.NoRebase, "no-rebase", false, "work it where it sits")
	c.Flags().StringVar(&o.Base, "base", "", "build on this workspace's tip (for parallel lanes)")
	c.Flags().StringVar(&o.In, "in", "", "refuse unless run from this workspace")
	return c
}

func finishCmd() *cobra.Command {
	var o core.FinishOpts
	var msg string
	c := group("work", &cobra.Command{
		Use:   "finish <id>",
		Short: "close out worked task: verify, set the message, mark done",
		Long: `Close out a worked task in one step: refuse if it's empty or conflicted, run the
repo's verify command (jt.verify), warn about untracked files, rewrite the message
keeping the trailers, and mark it done (or testing, with --testing). Nothing is
written unless every check passes. Exit 1 on failure, with the output's tail.`,
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			text, err := textValue(msg)
			if err != nil {
				return err
			}
			o.Message = text
			return report(repo.Finish(args[0], o))
		},
	})
	c.Flags().StringVarP(&msg, "message", "m", "", `commit message, "-" for stdin; default keeps the current one`)
	c.Flags().StringVar(&o.Testing, "testing", "", "what a person should check: ends at testing, not done")
	c.Flags().BoolVar(&o.NoVerify, "no-verify", false, "skip the verify command")
	c.Flags().BoolVar(&o.AllowEmpty, "allow-empty", false, "allow no code changes")
	return c
}

func doneCmd() *cobra.Command {
	return group("work", &cobra.Command{
		Use:               "done <id>",
		Short:             "mark done with no gates (for confirming testing, or moot tasks)",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.Done(args[0]))
		},
	})
}

func blockCmd() *cobra.Command {
	var options []string
	var recommend int
	c := group("work", &cobra.Command{
		Use:               "block <id> [question...]",
		Short:             "park a design fork, with options and a recommendation",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.Block(args[0], strings.Join(args[1:], " "), options, recommend))
		},
	})
	c.Flags().StringArrayVarP(&options, "option", "o", nil, "an option (repeatable)")
	c.Flags().IntVarP(&recommend, "recommend", "r", 0, "1-based option you recommend")
	return c
}

func verifyCmd() *cobra.Command {
	var set string
	c := group("work", &cobra.Command{
		Use:   "verify",
		Short: "run the repo's verify command, reporting only pass or the failure tail",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			if set != "" {
				return repo.SetConfig("jt.verify", set)
			}
			rep, err := repo.Verify()
			if err != nil {
				return err
			}
			printVerify(rep)
			if !rep.OK {
				return exitError{1}
			}
			return nil
		},
	})
	c.Flags().StringVar(&set, "set", "", "store the command in this repo's jj config (jt.verify)")
	return c
}

// ---------------------------------------------------------------- managing

func newCmd() *cobra.Command {
	var o core.NewOpts
	c := group("manage", &cobra.Command{
		Use:     "new <summary...>",
		Aliases: []string{"add", "todo"},
		Short:   "file a task",
		Args:    cobra.MinimumNArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			o.Summary = strings.Join(args, " ")
			body, err := textValue(o.Body)
			if err != nil {
				return err
			}
			o.Body = body
			res, err := repo.New(o)
			if err != nil {
				return err
			}
			if jsonOut {
				return report(res, nil)
			}
			fmt.Printf("%s %s\n", style("33", res.Task.ID), res.Task.Summary)
			return nil
		},
	})
	c.Flags().StringVarP(&o.Priority, "priority", "p", "", "P0..P3")
	c.Flags().StringVarP(&o.Scope, "scope", "s", "", "files it should touch")
	c.Flags().StringArrayVarP(&o.Blockers, "blocked-by", "b", nil, "blocking task (repeatable)")
	c.Flags().StringArrayVar(&o.Parents, "parent", nil, "parent revision (repeatable)")
	c.Flags().StringVar(&o.Body, "body", "", `detail, "-" for stdin`)
	c.RegisterFlagCompletionFunc("priority", fixed(core.Priorities...))
	c.RegisterFlagCompletionFunc("blocked-by", completeTasks)
	return c
}

func setCmd() *cobra.Command {
	return group("manage", &cobra.Command{
		Use:   "set <id> key=value...",
		Short: "update fields: status= priority= scope= summary= body= message= or any Trailer-Key=",
		Long: `Update fields. status, priority, scope and any other Trailer-Key are trailers; an
empty value clears one. summary is the first line, body the detail below it (the
same "body" as jt json), message both. body= and message= accept "-" for stdin.`,
		Args: cobra.MinimumNArgs(2),
		ValidArgsFunction: func(c *cobra.Command, args []string, s string) ([]string, cobra.ShellCompDirective) {
			if len(args) == 0 {
				return completeTasks(c, args, s)
			}
			var out []string
			if strings.HasPrefix(s, "status=") {
				for _, v := range core.Statuses {
					out = append(out, "status="+v)
				}
			} else if strings.HasPrefix(s, "priority=") {
				for _, v := range core.Priorities {
					out = append(out, "priority="+v)
				}
			} else {
				out = []string{"status=", "priority=", "scope=", "summary=", "body=", "message="}
			}
			return out, cobra.ShellCompDirectiveNoSpace | cobra.ShellCompDirectiveNoFileComp
		},
		RunE: func(_ *cobra.Command, args []string) error {
			var kvs [][2]string
			for _, kv := range args[1:] {
				k, v, ok := strings.Cut(kv, "=")
				if !ok {
					return fmt.Errorf("expected key=value, got '%s'", kv)
				}
				if lk := strings.ToLower(k); lk == "body" || lk == "message" {
					text, err := textValue(v)
					if err != nil {
						return err
					}
					v = text
				}
				kvs = append(kvs, [2]string{k, v})
			}
			return report(repo.Set(args[0], kvs))
		},
	})
}

func needsCmd() *cobra.Command {
	var replace bool
	c := group("manage", &cobra.Command{
		Use:               "needs <id> [blocker...]",
		Short:             "add blocker edges; --replace rewires them, with no blockers it clears",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: completeTasks,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.SetNeeds(args[0], args[1:], replace))
		},
	})
	c.Flags().BoolVar(&replace, "replace", false, "replace existing blockers rather than adding")
	return c
}

func deferCmd() *cobra.Command {
	return group("manage", &cobra.Command{
		Use:               "defer <id> [reason...]",
		Short:             "shelve a task: never ready, never raised again until revived",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.Defer(args[0], strings.Join(args[1:], " ")))
		},
	})
}

func decideCmd() *cobra.Command {
	var list bool
	var o core.DecideOpts
	c := group("manage", &cobra.Command{
		Use:   "decide [<id> [decision...]]",
		Short: "answer parked design forks: a TUI queue, or record one answer",
		Long: `With no arguments in a terminal, walk the blocked tasks in a TUI. With --list (or
when not a terminal), print the open forks as JSONL. With an id, record a decision:
it replaces the open question and unblocks the task in one step.`,
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			if len(args) > 0 {
				o.Text = strings.Join(args[1:], " ")
				return report(repo.Decide(args[0], o))
			}
			if !list && interactive() {
				return tui.Run(repo, tui.ScreenDecide, assetTemplate())
			}
			b, err := repo.Load()
			if err != nil {
				return err
			}
			for _, t := range b.ByPriority(false) {
				if t.Status == "blocked" {
					if err := printJSON(t.Full()); err != nil {
						return err
					}
				}
			}
			return nil
		},
	})
	c.Flags().BoolVar(&list, "list", false, "print open forks as JSONL")
	c.Flags().StringVarP(&o.Option, "option", "o", "", "choose this option key")
	c.Flags().BoolVar(&o.Moot, "moot", false, "the answer makes the task moot: mark it done")
	return c
}

func reopenCmd() *cobra.Command {
	return group("manage", &cobra.Command{
		Use:               "reopen <id> [reason...]",
		Aliases:           []string{"reject"},
		Short:             "send a task back to todo, saying why (rejecting a testing task)",
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			return report(repo.Reopen(args[0], strings.Join(args[1:], " ")))
		},
	})
}

func stripCmd() *cobra.Command {
	var msg string
	c := group("manage", &cobra.Command{
		Use:               "strip <id>",
		Short:             "remove jt's trailers: off the board for good, a clean commit",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: firstArgTask,
		RunE: func(_ *cobra.Command, args []string) error {
			text, err := textValue(msg)
			if err != nil {
				return err
			}
			return report(repo.Strip(args[0], text))
		},
	})
	c.Flags().StringVarP(&msg, "message", "m", "", `rewrite the message too, "-" for stdin`)
	return c
}
