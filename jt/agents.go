package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"jt/internal/core"
)

func nextCmd() *cobra.Command {
	var o core.NextOpts
	var explain bool
	c := group("run", &cobra.Command{
		Use:   "next [focus...]",
		Short: "what to work on: ready tasks by priority, clear of in-flight scope",
		Long: `The selection rule as a command: ready tasks by priority, skipping any whose scope
overlaps a doing task. Prints JSONL without bodies. --disjoint also keeps picks from
overlapping each other, for parallel dispatch. --explain adds the skipped tasks
and why to stderr.`,
		RunE: func(_ *cobra.Command, args []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			o.Focus = strings.Join(args, " ")
			picks, skipped := b.Next(o)
			for _, t := range picks {
				if err := printJSON(t.Brief()); err != nil {
					return err
				}
			}
			if len(picks) == 0 {
				fmt.Fprintln(os.Stderr, "jt: nothing ready")
			}
			if explain {
				for _, s := range skipped {
					fmt.Fprintf(os.Stderr, "jt: skipped %s: %s\n", s.ID, s.Reason)
				}
			}
			return nil
		},
	})
	c.Flags().IntVarP(&o.Limit, "limit", "n", 0, "at most this many")
	c.Flags().BoolVar(&o.Disjoint, "disjoint", false, "picks must not overlap each other")
	c.Flags().BoolVar(&explain, "explain", false, "report skipped tasks on stderr")
	return c
}

// Ref is how the working rules name the task: its id when there's one.
func (d briefData) Ref() string {
	if len(d.Tasks) == 1 {
		return d.Tasks[0].ID
	}
	return "<id>"
}

type briefData struct {
	Tasks  []*core.Task
	Lane   string
	Dir    string
	Base   string
	Verify string
}

func briefCmd() *cobra.Command {
	var lane, base string
	c := group("run", &cobra.Command{
		Use:   "brief <id>...",
		Short: "a complete worker prompt: the tasks plus how to work them",
		Long: `Print a complete prompt for a worker. An orchestrator can hand a subagent just
"cd <lane> && jt brief <id>, then follow it" and never hold the task body or the
working rules in its own context. --lane names a workspace (created if needed).`,
		Args:              cobra.MinimumNArgs(1),
		ValidArgsFunction: completeTasks,
		RunE: func(_ *cobra.Command, args []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			d := briefData{Base: base, Verify: repo.Config("jt.verify")}
			for _, q := range args {
				t, err := b.Resolve(q)
				if err != nil {
					return err
				}
				d.Tasks = append(d.Tasks, t)
			}
			if lane != "" {
				path, _, err := repo.Lane(lane)
				if err != nil {
					return err
				}
				d.Lane, d.Dir = lane, path
			}
			return briefTemplate.Execute(os.Stdout, d)
		},
	})
	c.Flags().StringVar(&lane, "lane", "", "workspace the worker runs in")
	c.Flags().StringVar(&base, "base", "", "workspace whose tip to build on")
	return c
}

func checkCmd() *cobra.Command {
	return group("run", &cobra.Command{
		Use:   "check",
		Short: "board consistency: orphaned claims, conflicts, divergence. Exit 1 on errors",
		Args:  cobra.NoArgs,
		RunE: func(*cobra.Command, []string) error {
			b, err := repo.Load()
			if err != nil {
				return err
			}
			ps := b.Check()
			if jsonOut {
				for _, p := range ps {
					if err := printJSON(p); err != nil {
						return err
					}
				}
			} else if len(ps) == 0 {
				fmt.Println("jt: board is consistent")
			} else {
				for _, p := range ps {
					fmt.Printf("%s %s %s: %s\n", p.Level, idStr(p.ID), p.Kind, p.Detail)
				}
			}
			if core.HasErrors(ps) {
				return exitError{1}
			}
			return nil
		},
	})
}

func reapCmd() *cobra.Command {
	var here bool
	c := group("run", &cobra.Command{
		Use:   "reap [id...]",
		Short: "recover abandoned claims: first time back to todo, second time blocked",
		Long: `Recover tasks left doing by workers that are gone. With no ids: tasks no workspace
is on (--here adds this workspace's @, when you know no worker is live in it). Tasks
on another workspace's @ are left alone. A second leak of the same task blocks it
for a person, since a third worker won't fix whatever's wrong. Exit 2 if any did.`,
		ValidArgsFunction: completeTasks,
		RunE: func(_ *cobra.Command, args []string) error {
			got, err := repo.Reap(args, here)
			if err != nil {
				return err
			}
			escalated := false
			for _, r := range got {
				escalated = escalated || r.Action == "escalated"
				if jsonOut {
					printJSON(r)
				} else {
					fmt.Printf("jt: %s %s\n", r.ID, r.Action)
				}
			}
			if escalated {
				return exitError{2}
			}
			return nil
		},
	})
	c.Flags().BoolVar(&here, "here", false, "include this workspace's @")
	return c
}

func laneCmd() *cobra.Command {
	return group("run", &cobra.Command{
		Use:   "lane <name>",
		Short: "print a named worker workspace's path, creating it if needed",
		Long: `Print the path of a named workspace, creating it beside the repo if needed and
running jt.setup there once (set with: jj config set --repo jt.setup "<cmd>").
Workers run in a lane so "jt start" never seizes the @ someone else works from.`,
		Args: cobra.ExactArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			path, created, err := repo.Lane(args[0])
			if err != nil {
				return err
			}
			if jsonOut {
				return printJSON(map[string]any{"path": path, "created": created})
			}
			fmt.Println(path)
			return nil
		},
	})
}

func landCmd() *cobra.Command {
	var into string
	var force, all bool
	c := group("run", &cobra.Command{
		Use:   "land <id>... | --all",
		Short: "move finished tasks from a lane into a workspace's line",
		Long: `Insert finished tasks just before a workspace's @, in the order given (--all: every
finished task not yet there, parents first), so they join that line and its tip
advances. Stops with exit 1 at the first conflict. Clean is only textual, so run
"jt verify" afterwards.`,
		ValidArgsFunction: completeTasks,
		RunE: func(_ *cobra.Command, args []string) error {
			if all {
				ids, err := repo.Unlanded(into)
				if err != nil {
					return err
				}
				if len(ids) == 0 {
					fmt.Println("jt: nothing to land")
				}
				args = ids
			} else if len(args) == 0 {
				return errors.New("land what? give ids, or --all")
			}
			for _, id := range args {
				if err := report(repo.Land(id, into, force)); err != nil {
					return err
				}
			}
			return nil
		},
	})
	c.Flags().StringVar(&into, "into", "default", "target workspace")
	c.Flags().BoolVar(&force, "force", false, "land an unfinished task")
	c.Flags().BoolVar(&all, "all", false, "every finished task not yet in the line")
	return c
}

// ---------------------------------------------------------------- grind

// grindCmd runs batches unattended, one fresh `claude -p` per batch. The point is
// the process boundary: a slash command can't clear its own context, so a long run
// inside one session pays for every earlier batch on every later turn. The loop
// itself only decides *whether* another batch should run, from the board, which
// costs no context at all.
func grindCmd() *cobra.Command {
	var o grindOpts
	c := group("run", &cobra.Command{
		Use:   "grind [focus...]",
		Short: "work batches unattended: one fresh claude -p per batch",
		Long: `Run batches of tasks unattended. Each round is a fresh "claude -p" running a slash
command (default /jt:burst), so context starts at zero every batch.

Stops when nothing is ready, the round cap is hit, the board stops changing, claude
exits nonzero, or a task leaks twice. Refuses the default workspace unless --here:
"jt start" would seize the @ you work from.`,
		RunE: func(_ *cobra.Command, args []string) error {
			o.focus = strings.Join(args, " ")
			return runGrind(o)
		},
	})
	f := c.Flags()
	f.IntVarP(&o.rounds, "rounds", "r", 10, "max batches")
	f.StringVarP(&o.dir, "dir", "C", "", "workspace to run in")
	f.StringVar(&o.lane, "lane", "", "named workspace to run in, created if needed")
	f.StringVar(&o.model, "model", "", "model per batch")
	f.StringVar(&o.budget, "budget", "", "per-round spend cap in USD")
	f.StringVar(&o.command, "command", "/jt:burst", "slash command per batch")
	f.StringVar(&o.logdir, "log", "", "log dir (default $XDG_STATE_HOME/jt/grind)")
	f.BoolVar(&o.here, "here", false, "allow the default workspace")
	f.BoolVarP(&o.dry, "dry-run", "n", false, "show what would run")
	c.RegisterFlagCompletionFunc("model", fixed("fable", "opus", "sonnet", "haiku"))
	return c
}

type grindOpts struct {
	rounds                                    int
	dir, lane, model, budget, command, logdir string
	focus                                     string
	here, dry                                 bool
}

func boardHash(b *core.Board) string {
	var rows []string
	for _, t := range b.Tasks {
		rows = append(rows, t.ID+":"+t.Status)
	}
	sort.Strings(rows)
	return strings.Join(rows, ",")
}

func runGrind(o grindOpts) error {
	if _, err := exec.LookPath("claude"); err != nil {
		return errors.New("claude is not on PATH")
	}
	r := repo
	if o.lane != "" {
		path, _, err := r.Lane(o.lane)
		if err != nil {
			return err
		}
		o.dir = path
	}
	if o.dir != "" {
		r = core.Repo{Dir: o.dir}
	}
	root, err := r.Root()
	if err != nil {
		return errors.New("not in a jj workspace")
	}
	r = core.Repo{Dir: root}
	// A secondary workspace stores .jj/repo as a file pointing at the store; the
	// default workspace has it as a directory.
	if fi, err := os.Stat(filepath.Join(root, ".jj", "repo")); err == nil && fi.IsDir() && !o.here {
		return fmt.Errorf("refusing to grind in the default workspace (%s): `jt start` would seize the @ you work from.\n  Use --lane <name>, -C <path>, or --here if you really mean this one", root)
	}
	logdir := o.logdir
	if logdir == "" {
		logdir = core.StateDir("grind")
	}
	stamp := time.Now().Format("20060102-150405")
	args := []string{"-p", "--output-format", "json", "--permission-mode", "bypassPermissions",
		// Deploying is the user's call, always: never a side effect of an unattended run.
		"--disallowedTools", "Bash(just deploy:*)"}
	if o.model != "" {
		args = append(args, "--model", o.model)
	}
	if o.budget != "" {
		args = append(args, "--max-budget-usd", o.budget)
	}
	prompt := o.command
	if o.focus != "" {
		prompt += " " + o.focus
	}
	args = append(args, prompt)
	readyCount := func(b *core.Board) int {
		picks, _ := b.Next(core.NextOpts{Focus: o.focus})
		return len(picks)
	}
	if o.dry {
		b, err := r.Load()
		if err != nil {
			return err
		}
		fmt.Printf("workspace: %s\nrounds:    %d\nlogs:      %s/%s-r<N>.json\nper round: claude %s\nready now: %d\n",
			root, o.rounds, logdir, stamp, strings.Join(args, " "), readyCount(b))
		return nil
	}
	if err := os.MkdirAll(logdir, 0o755); err != nil {
		return err
	}
	total, ran, stall, lastHash := 0.0, 0, 0, ""
	finish := func() error {
		tip, _ := r.Tip("")
		fmt.Printf("jt grind: spent $%.4f across %d round(s); tip %s\n", total, ran, tip)
		fmt.Println("jt grind: `jt land --all` from your own workspace brings the work over")
		return nil
	}
	for round := 1; round <= o.rounds; round++ {
		b, err := r.Load()
		if err != nil {
			return err
		}
		ready := readyCount(b)
		if ready == 0 {
			fmt.Printf("jt grind: nothing ready, stopping after %d round(s)\n", round-1)
			for _, t := range b.Tasks {
				if t.Status == "blocked" || t.Status == "testing" {
					fmt.Println(taskLine(t))
				}
			}
			return finish()
		}
		fmt.Printf("── round %d/%d, %d ready, %s\n", round, o.rounds, ready, time.Now().Format("15:04"))
		logPath := filepath.Join(logdir, fmt.Sprintf("%s-r%d.json", stamp, round))
		var out bytes.Buffer
		cmd := exec.Command("claude", args...)
		cmd.Dir = root
		cmd.Stdout, cmd.Stderr = &out, &out
		runErr := cmd.Run()
		os.WriteFile(logPath, out.Bytes(), 0o644)
		if runErr != nil {
			fmt.Printf("jt grind: claude failed (%v), stopping (log: %s)\n", runErr, logPath)
			return finish()
		}
		ran++
		var res struct {
			Cost   float64 `json:"total_cost_usd"`
			Result string  `json:"result"`
		}
		json.Unmarshal(out.Bytes(), &res)
		total += res.Cost
		fmt.Printf("   done, $%.4f (run total $%.4f), %s\n", res.Cost, total, logPath)
		lines := strings.Split(res.Result, "\n")
		if len(lines) > 20 {
			lines = lines[:20]
		}
		for _, l := range lines {
			fmt.Println("   " + l)
		}
		reaped, err := r.Reap(nil, true)
		if err != nil {
			return err
		}
		for _, rp := range reaped {
			fmt.Printf("   reap: %s %s (worker didn't close it out)\n", rp.ID, rp.Action)
			if rp.Action == "escalated" {
				fmt.Printf("jt grind: %s leaked twice, stopping: it needs a look\n", rp.ID)
				finish()
				return exitError{1}
			}
		}
		b, err = r.Load()
		if err != nil {
			return err
		}
		if h := boardHash(b); h == lastHash {
			stall++
			if stall >= 2 {
				fmt.Println("jt grind: board unchanged for 2 rounds, stopping")
				return finish()
			}
		} else {
			stall, lastHash = 0, h
		}
	}
	fmt.Printf("jt grind: hit the %d-round cap\n", o.rounds)
	return finish()
}

// ---------------------------------------------------------------- install

var markerRE = regexp.MustCompile(`(?ms)^# >>> jt tasks.*?^# <<< jt tasks <<<\n?`)

// upsertBlock replaces the marked block where it sits, or appends one: a block
// moved by hand stays where it was put.
func upsertBlock(path, block string) error {
	data, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	var out string
	if loc := markerRE.FindIndex(data); loc != nil {
		out = string(data[:loc[0]]) + block + string(data[loc[1]:])
	} else {
		rest := strings.TrimRight(string(data), "\n")
		if rest != "" {
			rest += "\n\n"
		}
		out = rest + block
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(out), 0o644)
}

const blockOpen = "# >>> jt tasks — managed by `jt install --jjui`, edits here will be overwritten >>>\n"
const blockClose = "# <<< jt tasks <<<\n"

func installCmd() *cobra.Command {
	var dir string
	var dry, jjui bool
	c := group("run", &cobra.Command{
		Use:         "install",
		Short:       "write the /jt:* slash commands, shell completions, and (--jjui) jjui actions",
		Args:        cobra.NoArgs,
		Annotations: map[string]string{"norepo": "1"},
		RunE: func(c *cobra.Command, _ []string) error {
			home, _ := os.UserHomeDir()
			env := func(k, def string) string {
				if v := os.Getenv(k); v != "" {
					return v
				}
				return def
			}
			if dir == "" {
				dir = env("JT_CLAUDE_DIR", filepath.Join(home, ".claude", "commands", "jt"))
			}
			zsh := filepath.Join(env("JT_ZSH_DIR", filepath.Join(home, ".local", "share", "zsh", "site-functions")), "_jt")
			fish := filepath.Join(env("JT_FISH_DIR", filepath.Join(home, ".config", "fish", "completions")), "jt.fish")
			bash := filepath.Join(env("JT_BASH_DIR", filepath.Join(home, ".local", "share", "bash-completion", "completions")), "jt")
			jjuiCfg := filepath.Join(env("JJUI_CONFIG_DIR", filepath.Join(home, ".config", "jjui")), "config.toml")
			if dry {
				fmt.Printf("slash commands → %s: %s.md\nremoved: %s.md\ncompletions: %s %s %s\n", dir, strings.Join(slashCommands, ".md "),
					strings.Join(obsoleteCommands, ".md "), zsh, fish, bash)
				if jjui {
					fmt.Printf("jjui actions → %s\n", jjuiCfg)
				}
				return nil
			}
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return err
			}
			for _, n := range slashCommands {
				if err := os.WriteFile(filepath.Join(dir, n+".md"), []byte(asset("commands/"+n+".md")), 0o644); err != nil {
					return err
				}
				fmt.Printf("wrote %s/%s.md  → /jt:%s\n", dir, n, n)
			}
			for _, n := range obsoleteCommands {
				if os.Remove(filepath.Join(dir, n+".md")) == nil {
					fmt.Printf("removed %s/%s.md\n", dir, n)
				}
			}
			root := c.Root()
			for path, gen := range map[string]func(*bytes.Buffer) error{
				zsh:  func(b *bytes.Buffer) error { return root.GenZshCompletion(b) },
				fish: func(b *bytes.Buffer) error { return root.GenFishCompletion(b, true) },
				bash: func(b *bytes.Buffer) error { return root.GenBashCompletionV2(b, true) },
			} {
				var buf bytes.Buffer
				if err := gen(&buf); err != nil {
					return err
				}
				os.MkdirAll(filepath.Dir(path), 0o755)
				if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
					return err
				}
				fmt.Printf("wrote %s\n", path)
			}
			if jjui {
				block := blockOpen + "# Task-aware log template — see `jt list --tree` for the same view in the shell.\n" +
					"[revisions]\ntemplate = '''\n" + assetTemplate() + "'''\n\n" + asset("jjui_actions.toml") + blockClose
				if err := upsertBlock(jjuiCfg, block); err != nil {
					return err
				}
				fmt.Printf("wrote jjui template + actions to %s\n", jjuiCfg)
				cfg := filepath.Join(home, ".config", "jj", "config.toml")
				if out, err := exec.Command("jj", "config", "path", "--user").Output(); err == nil {
					cfg = strings.TrimSpace(string(out))
				}
				if err := upsertBlock(cfg, blockOpen+asset("jjcolors.toml")+blockClose); err != nil {
					return err
				}
				fmt.Printf("wrote task colours to %s\n", cfg)
			}
			fmt.Println("\nRestart Claude Code (or start a new session) to pick up the commands.")
			return nil
		},
	})
	c.Flags().StringVar(&dir, "dir", "", "Claude commands dir")
	c.Flags().BoolVar(&jjui, "jjui", false, "also write jjui actions and jj colours")
	c.Flags().BoolVarP(&dry, "dry-run", "n", false, "show what would be written")
	return c
}
