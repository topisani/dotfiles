---
name: orchestrate
description: >-
  Run a managed, optionally-autonomous task-orchestration session. The main
  session keeps its own context thin, tracks the backlog as jt tasks (jj
  changes), and delegates each task to a fresh subagent that commits its work
  with jj/jt. Use when the user wants to kick off managed multi-task work,
  "work through these tasks / the backlog", "run autonomously while I'm away",
  "manage these as tasks and delegate", or keeps a rolling list of small
  features/bugs to hand off. Not for one-off single edits.
---

# Orchestrate

You are the **orchestrator**: keep the backlog true, dispatch each task to a
fresh worker, land the result, repeat until the backlog is empty or everything
left is blocked on the user. Workers read, edit, and commit. You stay thin so
you can run for hours.

**Never stop early.** While any unblocked task remains, keep dispatching.

If `jt` isn't on PATH, say so and stop. Don't reimplement it by hand. `jt --help`
is the command reference; this file is only the judgment `jt` can't make for you.

A task *is* a jj change whose description ends in a `Task-Status:` trailer. The
backlog lives in `jj log`: no files to create, nothing to keep in sync, and
nothing in your context that `jt` can't give you back after a compaction.

## Who enforces what

These are code, not conventions, so don't re-check them by hand:

| Rule | Enforced by |
| --- | --- |
| Pick by priority, skip scope that overlaps in-flight work | `jt next` |
| No starting blocked, deferred, finished, or already-claimed tasks, or ones with unfinished blockers | `jt start` |
| A worker can't claim from the wrong workspace, even if its `cd` didn't persist | `jt start --in`, written by `jt brief --lane` |
| No finishing on an empty change, a conflict, or a failed verify; untracked files reported | `jt finish` |
| Abandoned claims reset; a second leak blocks the task | `jt reap` |
| Worker working rules, including the 3-line return cap | `jt brief` |
| Verify output kept out of context (pass, or the failure tail) | `jt verify` |

Set the repo up once: `jt verify --set "<command>"`, and if a fresh workspace
needs dependencies, `jj config set --repo jt.setup "<install command>"`. Without
`jt.verify`, workers fall back to whatever `CLAUDE.md` says, unenforced.

## Main loop

```
loop:
  jt check                      # errors? orphaned -> jt reap; conflict/divergent -> look
  fold new user input in:       jt new "<summary>" -p <P> -s "<scope>" --body "<detail>"
  jt next -n 1                  # or -n N --disjoint to fill parallel lanes
  nothing ready:
    blocked tasks remain  -> stop, summarize, point at `jt decide` / `/jt:decide`
    otherwise             -> stop, summarize. testing is the user's to confirm,
                             deferred is theirs to revive
  dispatch (below), then:
    worker reported done/testing -> jt land <id> && jt verify
    worker reported blocked      -> carry on; it's on the board
    anything else, or task still doing -> Failure, below
  goto loop
```

Land each verified change immediately rather than stockpiling for a big merge.
Batch design questions up front before a long stretch; mid-run they go on the task
(`jt block`) and don't stop other work. New input mid-run gets filed with a
priority and doesn't preempt the current task unless it's urgent (`-p P0`).

## Dispatching

**Workers always run in a lane**, a persistent named workspace, never yours. `jt
start` runs `jj edit`, which seizes the `@` of whichever workspace it's run from.
Attended `/jt:start` in your own workspace is the only exception.

```
Agent prompt:  Run `jt brief <id> --lane w1 --base default` and follow it.
               <diagnosis, if this is a retry>
```

<<<<<<< Updated upstream
**Delegate the SEARCH, not only the work.** Before designing anything that
introduces a new name, fan out read-only agents to answer "does a general
mechanism for this already exist, and where?" and take back a few lines. The
reason this step gets skipped is that searching costs the ORCHESTRATOR's
context — the one genuinely scarce resource in a long run. Subagent context is
free and never reaches you, so the constraint driving the skip already has a
tool that removes it. Hoarding design while delegating implementation is
backwards: design is the half that needs the wide read.

**What a worker inherits depends on its agent type — verified, not assumed.**
A `general-purpose` subagent receives the project `CLAUDE.md`, the user's global
`CLAUDE.md` and the memory index, injected as a `claudeMd` block. An `Explore`
subagent receives NONE of them. So a rule that must reach a *searching* agent
belongs in its dispatch prompt; a rule that must reach an *implementing* agent
can live in `CLAUDE.md`. Re-probe rather than trusting this table if the harness
changes — a delegated agent reporting on its own context is evidence about that
agent only, and two of them disagreed before this was measured.

Worker prompt should cover:
- **GOAL + SCOPE** — the outcome and an entry-point file, not the exact edits
- **CONSTRAINTS** — API/patterns to follow, what not to touch
- **SEARCH BEFORE DESIGN** — establish whether a general mechanism already
  exists before introducing a new one. If it does, use it and name it in the
  commit message. If it genuinely does not, say so explicitly before building
  one. The trigger is **"am I about to introduce a name that does not exist
  yet"** — a new function, flag, attribute, field, class, selector or concept —
  **not** blast radius or file count. A one-line change that mints a concept
  needs the search; a fifty-file change that only calls existing things does
  not. A local picture always feels complete, and on any codebase larger than a
  context window it will be wrong; only a mechanical search step catches that.
- **DESIGN** — resolve a fork alone once the search above has shown that
  nothing already answers it (record the choice + why in the commit message);
  block instead of guessing when it's genuinely up to the user: `jt block <id>
  "<the question, options, your recommendation>"` and return early. Blocked
  tasks accumulate for a single `/jt:decide` pass rather than pausing the run.
- **BUGS** — reproduce with a failing test first, then fix, keep the test
- **VCS** — jj only, never `git commit`. `jt start` runs `jj edit`, seizing
  the *invoking* workspace's `@` — so **every** worker, sequential or
  parallel, is told which workspace to `cd` into before it does anything
  else. Never let a worker inherit your own cwd — that's the default
  workspace, and workers must never edit its `@` out from under you.
  First action once in its workspace: `jt start <id>` — claims the task
  (marks `doing`, rebases onto that workspace's own tip, `jj edit`s it). A
  task filed from a different workspace can have a stale parent; that's
  harmless, `jt start` rebases it. If it reports it couldn't rebase, that's a
  stop-and-report, not something to push through. `jj file track` any new
  file. Finish with the project's verify command (exit 0 only), `jt set <id>
  body=-` (piping a heredoc from stdin: summary line, blank line, then a
  clean implementation summary — a couple of short paragraphs max, the change
  and its motivation, not a log of the work) to rewrite the message, then `jt
  done <id>` — marks it done and moves it off the default board. **Never call
  raw `jj describe <id>` on a jt-tracked change** — it replaces the whole
  description and silently wipes the `Task-Status`/`Priority`/`Scope`
  trailers, and `jt` then can't find the task at all (recoverable, but avoid
  it: re-describe with the trailer block manually appended). Also never feed
  `body=-` a heredoc that itself contains `Task-Status:`/`Priority:`/`Scope:`
  lines — `jt set` re-adds the trailer block itself, so doing so doubles it.
  The trailers stay on the
  commit until a later `/jt:cleanup` pass runs `jt strip`, so a `done` commit
  is not yet the clean landed prose the trailers will eventually give way to
  — that's a separate, later pass, not part of this worker's job. If the
  change genuinely needs the user's own eyes (a UI change, anything verify
  can't judge), `jt set <id> status=testing` instead and say so in the return
  report — that still counts as finished for sequencing, but leave it for the
  user to close out, not you.
- **VERIFY** — the project's verify command; exit code is truth, ignore stale
  LSP diagnostics
- **RETURN** — **at most 3 lines, no diffs, no file contents, no play-by-play**
  — the change id, done/testing/blocked, one line of what changed and why.
  Everything longer belongs in the commit message, where it costs you nothing
  and outlives the run. This is a hard cap, not a style note: a worker that
  returns its reasoning spends your context on every remaining round of the
  run. Data for the orchestrator, not a chat reply.
||||||| Stash base
Worker prompt should cover:
- **GOAL + SCOPE** — the outcome and an entry-point file, not the exact edits
- **CONSTRAINTS** — API/patterns to follow, what not to touch
- **DESIGN** — resolve a fork alone when the choice is discoverable (record
  the choice + why in the commit message); block instead of guessing when
  it's genuinely up to the user: `jt block <id> "<the question, options, your
  recommendation>"` and return early. Blocked tasks accumulate for a single
  `/jt:decide` pass rather than pausing the run.
- **BUGS** — reproduce with a failing test first, then fix, keep the test
- **VCS** — jj only, never `git commit`. `jt start` runs `jj edit`, seizing
  the *invoking* workspace's `@` — so **every** worker, sequential or
  parallel, is told which workspace to `cd` into before it does anything
  else. Never let a worker inherit your own cwd — that's the default
  workspace, and workers must never edit its `@` out from under you.
  First action once in its workspace: `jt start <id>` — claims the task
  (marks `doing`, rebases onto that workspace's own tip, `jj edit`s it). A
  task filed from a different workspace can have a stale parent; that's
  harmless, `jt start` rebases it. If it reports it couldn't rebase, that's a
  stop-and-report, not something to push through. `jj file track` any new
  file. Finish with the project's verify command (exit 0 only), `jj describe
  <id>` to a clean implementation summary (a couple of short paragraphs, max —
  the change and its motivation, not a log of the work), then `jt done <id>` —
  marks it done and moves it off the default board. The trailers stay on the
  commit until a later `/jt:cleanup` pass runs `jt strip`, so a `done` commit
  is not yet the clean landed prose the trailers will eventually give way to
  — that's a separate, later pass, not part of this worker's job. If the
  change genuinely needs the user's own eyes (a UI change, anything verify
  can't judge), `jt set <id> status=testing` instead and say so in the return
  report — that still counts as finished for sequencing, but leave it for the
  user to close out, not you.
- **VERIFY** — the project's verify command; exit code is truth, ignore stale
  LSP diagnostics
- **RETURN** — **at most 3 lines, no diffs, no file contents, no play-by-play**
  — the change id, done/testing/blocked, one line of what changed and why.
  Everything longer belongs in the commit message, where it costs you nothing
  and outlives the run. This is a hard cap, not a style note: a worker that
  returns its reasoning spends your context on every remaining round of the
  run. Data for the orchestrator, not a chat reply.
=======
The brief creates the lane if needed and carries the task body, the working rules,
and the return format, so none of that passes through your context. `--base
default` builds the task on your line, including everything already landed.
>>>>>>> Stashed changes

- **Delegate investigation, not transcription.** A task goes out as a goal, not a
  pre-spec'd diff. If you investigate first and hand over edits to transcribe,
  you've done the expensive part yourself. Only true one-liners stay with you, and
  a task that already failed once (see Failure).
- **Model:** strong enough to get it right the first time; downshift only for
  mechanical or read-only work; escalate on any repeat failure.
- **Reuse a warm worker** (SendMessage) for a string of small related fixes. Its
  orientation cost is already paid.

**Parallel:** one lane per worker, `w1`, `w2`..., with tasks from `jt next -n N
--disjoint`. Overlapping scope must be serialized even across lanes. A clean landing
is textual, not semantic: `jt verify` after each one. Don't rewrite a commit another
live lane's `@` is based on.

**Batching:** a worker's first minutes go on orienting, and every fresh worker pays
that again. Give one worker several *small* tasks in related scope: `jt brief <id>
<id> ... --lane w1 --base default`, up to about 8. Anything needing real design goes
alone: a batch that stalls on task 3 leaves 4-8 unstarted. Land them in order.

**Read-only scouting** is safe to parallelize freely, and needs no lane: fan out
investigators rather than reading serially yourself.

## Your context is the scarce resource

Workers start fresh and their transcripts never reach you. Only three things
accumulate, so police them: the board (`jt next` and `jt json -q`, never bare `jt
json`, which is about 10x larger), worker reports (`jt brief` caps them at 3 lines per
task), and your own file reads (delegate them). You need a task body only when you
are root-causing a failure yourself.

Compact proactively at natural boundaries (a task landed). You can't invoke
`/compact` yourself, so remind the user. Everything durable is in jj.

## Reviewing results

You spot-check against the board, not the diff: `jt finish` has already refused
empty and unverified work, so a task that's `done` or `testing` passed. Pull the
diff only if something looks off or the task is high-stakes. For complex or important
tasks, offer an independent review: a fresh subagent reviews the diff before you land.

`testing` means the change needs the user's eyes. It counts as finished for
sequencing, and you land it, but never set it to `done` yourself.

## Failure

A task still `doing` after its worker returned is the failure that hides: it isn't
`ready`, so the run could end declaring victory with work half-claimed. `jt reap <id>`
it (its `@` is still the lane, so plain `jt check` won't flag it). A second leak
blocks it for the user.

Don't blind-retry. Before re-dispatching:

1. `jt set <id> status=investigating`, so nothing else picks it up.
2. Read the code and find the actual cause.
3. Add the diagnosis to the body (`jt set <id> body=-`, stdin), set `status=todo`,
   and re-dispatch: stronger model, a reproduction test, your root cause up front.

Still stuck after that: `jt block <id> "<reason>"` and keep going on other tasks.

## Leaving someone else's work alone

- Don't run `/jt:cleanup` or `jt strip` unless asked. `done` tasks keep their
  trailers until the user's cleanup pass, and stay unpushable (`git.private-commits`)
  until then. Mention it at a stopping point if they've piled up.
- Don't squash, move bookmarks, or deploy.
- Project verify commands and footguns belong in that project's `CLAUDE.md`, so
  future workers inherit them. Write new traps there.

## Nobody watching

This skill's honest limit: an unattended session eventually compacts on its own
terms. For a run nobody is watching, hand off to **`jt grind --lane <name> -r N`**: a
loop running one fresh `claude -p "/jt:burst"` per batch, so context resets between
batches and no supervisor accumulates. It decides between rounds from the board at no
context cost, reaps leaks, logs cost, and stops itself. `jt land --all` afterwards.
