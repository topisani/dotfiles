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
fresh worker subagent, verify the result, land it, repeat until the backlog is
empty or everything left is blocked on the user. Workers do the reading, the
editing, and the committing — via `jt`, which wraps jj (general jj mechanics
are in the `jj-workflow:jj-concepts` skill; `jt --help` for jt's own command
surface). You stay thin so you can run for hours without losing the plot.

**Never stop early.** While any unblocked task remains, keep dispatching.

## Setup

Requires a jj repo and `jt` on PATH (a task tracker built on jj changes — see
`jt --help`). If `jt` is missing, say so and stop; don't reimplement its
bookkeeping by hand with a markdown file.

No project file to create: a task *is* a jj change (a commit whose
description ends in a `Task-Status:` trailer block), so the backlog lives in
`jj log` itself — no committed-vs-ignored decision, nothing to add to
`.gitignore`.

Migrating an old `.orchestrate/BACKLOG.md`: file each surviving entry with
`jt new` (carry over priority/scope/body), then delete the file — a one-time
step, not a recurring one.

## State

**Poll with `jt json -q`, never bare `jt json`.** `-q` drops the `body` field:
on a ~30-task board that's 11KB instead of 99KB — measured, ~10x — and the
board is re-read every loop iteration, so bare `jt json` spends most of your
context on the bodies of tasks you are not running. You never need a body
yourself: the worker reads its own with `jt show <id>` inside its own context.
Reach for a body only when *you* are root-causing a failure (see Failure).

`jt json -q` is the source of truth — re-run it after any compaction instead of
trusting memory. Each line is one task: `id` (the jj change id — same
identifier throughout, nothing to keep in sync separately), `status` (`todo
ready doing investigating blocked testing deferred done`), `priority`
(`P0`..`P3`), `scope` (files it's expected to touch — collision detection is
based on this, trust it over guessing from the title), `needs` (unfinished
blockers), `ready` (no unfinished blockers and status `todo`/`ready`). Bare
`jt json` adds `body`.

Two statuses a worker leaves behind rather than the orchestrator setting:
`testing` (worker finished but the change needs the user's own eyes —
typically a UI change verify can't judge — so it set `status=testing` instead
of calling `jt done`; treat that exactly like `done` for sequencing purposes,
including as the new tip, but leave it alone — it's the user's to resolve, not
yours to re-dispatch or nudge to `done`) and `deferred` (the user punted on a
blocked question via `/jt:decide`; never dispatch it, never re-raise it —
that's the whole point of the status).

No `BACKLOG.md`, no `JOURNAL.md`, no `QUESTIONS.md`: `jt evo <id>` is a
task's history (status/priority/checklist changes over time), the landed
commit is the permanent record, and a blocked task carries its open question
inline — `jt block <id> "<question, with options and a recommendation>"`
appends it to the description instead of it living in a separate file.

**Compact proactively** at natural boundaries (task claimed, task landed)
instead of waiting for the context ceiling — everything durable already lives
in jj; nothing in context is unrecoverable from `jt json -q`.

**Your context is the scarce resource, not the workers'.** Each worker starts
fresh and its transcript never reaches you; only what you read yourself and
what workers report back accumulates. So the three inflows to police are: the
board poll (use `-q`), worker return reports (bound them — see RETURN), and
your own file reads (delegate them). Everything else is free.

## Main loop

```
loop:
  jt json -q                                 # reconcile — reread, don't trust memory
  fold in new input not yet on the board: jt new "<summary>" -p <P> \
    -s "<scope>" --body "<detail>"
  pick highest-priority ready:true task whose scope doesn't collide with a
  status:doing task
  several small ready tasks with related scope? dispatch them as ONE batch to
  one worker (see Batching) instead of one worker each
  if none ready:
    any status:blocked remains -> stop, summarize, point at /jt:decide
    only testing/deferred/done remain -> stop, summarize (done) — testing
      tasks are the user's to confirm, deferred ones are theirs to revive
  dispatch to a worker (below)
  verify the result
  success -> sequential: jt done (or jt set status=testing, for a change that
             needs the user's own eyes) already left the finished commit as
             the new tip. parallel: rebase it onto the default workspace's
             tip yourself, then dispatch a verify pass (below) — jt does not
             do this for you.
  failure -> root-cause it yourself before re-dispatching — don't blind-retry
  goto loop
```

Land each verified change immediately — don't stockpile unmerged work for a
big merge later. Batch design questions up front before a long autonomous
stretch; mid-run questions go inline on the task (`jt block`) and don't block
other work. New user input mid-run is filed with `jt new` and a priority — it
doesn't preempt the current task unless flagged urgent (`-p P0`).

## Delegating to workers

**Delegate investigation, not transcription.** A task goes to a worker as a
goal and an entry point, not a pre-spec'd diff — the worker reads the code,
decides the approach, and implements it. If you investigate first and hand the
worker a spec to transcribe into edits, you've done the expensive part
yourself and defeated the reason to delegate. Only true one-liners stay with
you.

Exception: a task that already failed once. Then investigate and root-cause it
yourself before re-dispatching (see Failure below).

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

Model: default to one strong enough to get it right on the first pass;
downshift only for mechanical or read-only work; escalate on any repeat
failure.

### Batching

One task per worker is the default, not a rule. A worker's first minutes are
spent orienting in the repo, and that cost is paid again by every fresh
worker — so when several *small* ready tasks sit in related scope, hand the
lot to one worker and let it work them back to back, exactly as `/jt:burst`
does inline (`jt start` each in turn; the run accumulates as a clean line
because each claim rebases onto the tip the last one left). Cap a batch at
about 8, and keep it to tasks whose scopes are related — one worker holding
two unrelated areas in context is worse than two workers.

Batch only *small* tasks. Anything needing real design or a wide diff goes
alone: a batch that stalls on task 3 leaves tasks 4-8 unstarted and their
claims to clean up.

Read-only investigation/scouting is safe to parallelize freely — fan out
several investigators at once rather than reading serially yourself. If live
edits (a worker mid-task, your own WIP `@`) would confuse a scout's read of
the tree, give it `isolation: "worktree"` — the jj plugin bridges this to a
throwaway `jj workspace`, created and torn down automatically, no manual `jj
workspace add`/`forget` needed. Fine for scouting since it needs no
`node_modules`/verify; not a fit for write-workers (see below).

## jj specifics for this workflow

General jj mechanics (squash, absorb, bookmarks, rebase, conflicts) are in the
`jj-workflow:jj-concepts` skill — don't re-derive them here. These are the
orchestration-only rules:

- Trailers are jt's storage, not manual bookkeeping: `Task-Status`,
  `Priority`, `Scope` live in the description from filing all the way through
  `done` — `jt done` only flips the status trailer, it doesn't strip. `jt
  strip` (normally run in a batch via `/jt:cleanup`, not part of this loop)
  is what removes them and leaves clean prose only. Never hand-edit the
  trailer block — go through `jt set`/`jt start`/`jt done`/`jt strip`/`jt
  block`.
- Default to **sequential** dispatch, working directly in the default
  workspace — `jt done` leaves the finished commit as the new tip and there
  is no separate landing step. Only run workers in parallel when their
  `scope` fields are disjoint — overlapping scope must be serialized even
  across workspaces.
- A parallel write-worker needs a **persistent** workspace (`jj workspace
  add`, deps installed once, reused) — `jt start` edits *that* workspace's
  `@`, so each parallel worker needs its own. A throwaway one (including
  `isolation: "worktree"`) has no `node_modules` and can't run verify.
- **Parallel landing is on you, not jt.** Each workspace's `jt start`
  rebases onto *that workspace's own* tip, so parallel workers build
  divergent lines that never converge by themselves. Once a parallel task is
  `done`, rebase it onto the default workspace's current tip yourself (`jj
  rebase -r <id> -d <default-tip>` — one line of output, fine to run
  directly) — jj's merge is textual, not semantic, so a clean rebase doesn't
  guarantee the code still works. Don't run the verify command yourself to
  check: dispatch a worker into the *same persistent workspace* the task was
  built in (it already has `node_modules`/deps installed — `isolation:
  "worktree"` doesn't) to run verify and report the exit code, same as any
  other task dispatch. This is safe to do concurrently with other live
  workers, as long as they're positioned on their own tip and you never touch
  a workspace whose `@` is still mid-task. The one thing that still needs a
  quiet window: rewriting a commit some *other live* workspace's `@` is
  based on.

## Verify gate

Default self-verify: the worker runs the verify command and only calls `jt
done` (or `jt set status=testing`, when the change needs the user's own eyes)
on exit 0 — a task still `doing` after a worker returns means verify didn't
pass (or the worker forgot), not that it's fine. You spot-check two things
against `jt json -q`, not the diff: the task is off the board or
`status:testing` (`done` tasks are filtered out of the default board view —
they still carry their trailers, so `jt json -q -a` or `jt evo <id>` still
shows them until a later `jt strip`), and `"empty":false` — `jt done` warns on
an empty change the same way `/jt:start` treats that warning as
stop-and-report, and an empty-but-`done` task is the cheapest sign a worker
misfired. Pull the full diff only when something looks off by these checks or
the task is high-stakes. For complex/important tasks, offer an
independent-reviewer pass instead (a fresh subagent runs the gate and reviews
the diff before `jt done`).

A task still `doing` after its worker returned is the one failure that hides:
it isn't `ready:true` any more, so the next loop iteration skips it and the
run can end declaring victory with work half-claimed. Check for `doing` tasks
with no live worker every iteration. First time: reset it (`jt set <id>
status=todo`, diagnosis appended) and let it be re-dispatched. Same task
leaking twice: stop and look at it yourself — something is wrong that a third
worker won't fix either.

## Failure & blockers

Don't blind-retry a failed worker. Read the code, find the actual cause, and
re-dispatch with that diagnosis baked in (or fix a one-liner inline) — leave
the task claimable again (`jt set <id> status=todo`) with the diagnosis added
to its description first, so the next worker doesn't repeat the investigation.
While you're the one root-causing it, `jt set <id> status=investigating`
rather than leaving it `todo`/`ready` — otherwise it's still `ready:true` and
a later loop iteration will happily hand it to a fresh worker out from under
you. A repeat failure means escalate, not re-patch cheaply: a stronger model,
a reproduction test, your own root-cause up front. Still stuck after that →
`jt block <id> "<reason>"` and keep going on other ready tasks — `/jt:decide`
drains these with the user later.

## Project notes

Per-project verify commands and footguns belong in that project's `CLAUDE.md`,
not here — write discovered traps there so future runs and workers inherit
them.

## Cross-run habits

- Squash a small fix into its feature when clean (`jj squash --from <fix>
  --into <feature> --use-destination-message`); leave it as a standalone
  fixup if it'd need real conflict resolution.
- `/jt:cleanup` (tidy `done` commit messages, then `jt strip` them) is a
  separate, user-invoked pass, not part of this loop — `done` tasks pile up
  with their trailers still on, and that's expected. Don't run it yourself
  unless asked; do mention it exists if `jt json -q -a` shows a pile of
  `done` tasks at a natural stopping point.
- You can't self-invoke `/compact` — proactively remind the user to run it at
  natural boundaries. Which is the honest limit of this skill for a run
  nobody is watching: an unattended session eventually compacts on its own
  terms or hits the ceiling. For that case hand off to **`jt grind`** instead
  — a shell loop that runs one fresh `claude -p "/jt:burst"` per batch, so
  context resets between batches and no supervisor accumulates at all. It
  stops on its own when nothing is ready, decides between rounds from `jt json
  -q` at zero context cost, and logs each round's result and cost. Use this
  skill when someone is in the loop, `jt grind -C <workspace> -r N` when
  nobody is. (`jt grind --help`. It refuses to run in the default workspace —
  `jt start` would seize the `@` the user works from.)
- For a run of several small fixes, prefer reusing one warm worker (via
  SendMessage) over a fresh spin-up each time — the same economy as Batching,
  applied to tasks that arrive one at a time instead of all at once.
- `jt evo <id>` is the fast way to sanity-check what actually happened to a
  task across a long run, without re-reading the whole conversation.
