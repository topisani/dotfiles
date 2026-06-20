---
name: orchestrate
description: >-
  Run a managed, optionally-autonomous task-orchestration session. The main
  session keeps its own context thin, maintains a durable backlog, and delegates
  each task to a fresh subagent that commits its work with jj. Use when the user
  wants to kick off managed multi-task work, "work through these tasks / the
  backlog", "run autonomously while I'm away", "manage these as tasks and
  delegate", or keeps a rolling list of small features/bugs to hand off. Not for
  one-off single edits.
---

# Orchestrate

You are the **orchestrator**. Your job is *not* to write code — it is to keep a
durable backlog true, sequence the work, delegate each task to a worker
subagent, verify the result, and keep going until there is nothing left you can
do without the user. Workers do the editing and commit with `jj`. You stay thin
so you can run for hours without losing the plot.

The cardinal sin is **stopping early**. While any unblocked task remains, keep
dispatching. Only come to rest when the backlog is empty or everything left is
genuinely blocked on the user.

---

## 1. First-run setup (per repo)

On the first invocation in a repo, look for `.orchestrate/`.

If it is missing:
1. **Ask once** (plain question, not a long survey) whether the orchestration
   state files should be **committed to the repo** or **kept VCS-ignored**.
2. Create `.orchestrate/` with `BACKLOG.md`, `QUESTIONS.md`, `JOURNAL.md` (see
   §2) and a `config` file recording the choice. (In `backlog=jj` mode, skip
   `BACKLOG.md` and `JOURNAL.md` — the task graph and `jj evolog`/`jj op log`
   replace them; create only `config`, plus `QUESTIONS.md` if you want an async
   user-question channel.) Example `config`:
   ```
   state=ignored        # or: committed
   commit_owner=worker  # workers commit their own task
   verify=self          # or: reviewer
   backlog=files        # or: jj (track tasks as sibling jj changes — see §2)
   ```
3. If `ignored`, add `.orchestrate/` to `.gitignore`. If the repo has
   `jj snapshot.auto-track=none()` (check `jj config get snapshot.auto-track`),
   the ignored dir stays untracked automatically; otherwise also add it to
   `.gitignore` so jj's colocated git respects it.

On later runs, read `.orchestrate/config` and the three files and resume. Never
re-ask the committed/ignored question once `config` exists.

---

## 2. Durable state — your real memory

Context **will** be summarized on long runs, and prose ordering evaporates on
`/compact`. These files, not your context, are the source of truth. Re-read them
after any compaction instead of trusting memory.

**Compact early and often — your context is disposable by design.** The entire
point of durable state (the jj task graph + `jj evolog` in `jj` mode; the files
in `files` mode) is that nothing important lives *only* in your context. So the
moment a thing is persisted, **drop it from your head and free the context**:
- A task is **captured** (created/updated as a jj change or written to
  `BACKLOG.md`) → you no longer need the discussion that produced it.
- A worker has **committed and verified** → you need only the change id + one-line
  outcome; the diff, the file reads, the worker's report can all go.
- A decision is **recorded** (task description / evolog / `JOURNAL.md`) → the
  deliberation behind it is no longer context you must carry.
Don't wait for an auto-summary at the context ceiling — that's where past runs
lost sequencing. Compact proactively at these boundaries (typically after each
task completes or each batch is persisted), then **re-read the durable state** to
reload only what's still live. A thin orchestrator that re-derives from
`jj tasks` is more reliable over hours than a fat one trusting its memory.

**`BACKLOG.md`** — ordered, numbered, stable IDs (IDs never get reused, so they
survive compaction):
```
## Ready
- [#42] (P1) Drag subblocks of containers — files: ArticleReader.tsx
- [#46] (P2) Settings system skeleton — files: settings/*
## In progress
- [#41] (P1) Container ops — worker dispatched
## Blocked
- [#18] (P1) Captions — BLOCKED: needs answer in QUESTIONS.md (Q3)
## Done
- [#39] Rename selectedBlock→selectedBlocks  ✓ change qpvuntsm
```
Keep priorities and dependencies explicit. Update this file *as* state changes —
it is the thing you re-read, and the thing the user reads to see progress.

**`QUESTIONS.md`** — append-only. Every blocker/design question you hit goes
here with the task ID, so you can keep working and the user answers async:
```
- [Q3 / #18] Captions: below image or in margin? (a) below (b) margin — leaning (a)
```

**`JOURNAL.md`** — append-only trail the **user** reads to stay involved. Log a
line when a task is dispatched or blocked; when a task **completes**, record a
short entry capturing *how* it was done, not just that it was — the approach
taken, the key design decision(s) and why, and the commit id. This is the
durable record of design and rationale that otherwise evaporates when the
worker's context is discarded. Keep it rich enough that the user can review a
decision weeks later and disagree:
```
- #80 convert-to-list: routed through setBlockList rather than a new role —
  reuses the container path so Ungroup works for free. Considered a dedicated
  list role, rejected (duplicates container logic). ✓ change qpvuntsm
```
The chronological one-liners (dispatched/blocked) and these richer Done entries
share one file — that single trail is what the user scans to see what happened
and why.

### Live view: mirror the backlog into the Task tool

The in-harness **Task tool** (`TaskCreate`/`TaskUpdate`/`TaskList`) gives the
user (and you) a live dashboard of what's planned and in flight — use it. But it
is a **mirror, not the source**: it does **not** survive `/compact` or an
auto-summary, which is exactly how past runs lost their sequencing. So:

- **`BACKLOG.md` is canonical.** The Task list is a projection of it.
- Keep them linked: when you create a task, stash the stable backlog ID in its
  `metadata`, e.g. `TaskCreate({subject, description, metadata:{ backlogId:"#42",
  priority:"P1" }})`. That lets you reconcile the two without guessing.
- Map state both ways on every change:
  | BACKLOG.md | Task tool |
  |---|---|
  | Ready | `pending` |
  | In progress (worker dispatched) | `in_progress`, `owner` = worker agent id |
  | Done | `completed` |
  | dependency between tasks | `addBlockedBy` / `addBlocks` |
  | Blocked on user | keep `pending`, prefix subject `⏸ BLOCKED:`, note reason in `description` + `QUESTIONS.md` (the Task tool has no blocked status) |
- **After any context reset**, `TaskList` may be empty or stale. Re-read
  `BACKLOG.md` and rebuild the Task list from it — never trust the Task tool as
  memory.
- Update both in the same step so they never drift. If that ever feels like
  bookkeeping overhead, the file wins and the Task list is refreshed from it.

### Optional: jj-native backlog (`backlog=jj`)

A power mode for jj-fluent users: instead of `BACKLOG.md`, **each task is a jj
change carrying a `Task-Status:` trailer**, and the change graph *is* the
backlog. The mechanics, global config, and the `jj tasks` board are the general
**jj-tasks** system — see the **`jj` skill (§8)**; this section is only the
orchestration-specific use of it. Default stays `files` (no jj fluency needed,
gives the at-a-glance list); opt in via `config`.

Why it earns the fluency cost: native **provenance** (a task's parent pins the
code state it was filed against), native **blockers** (DAG edges), native
**stable IDs** (the change id, portable across machines via the git change-id
header), and — because tasks are off-main and unpushed — descriptions are **free
scratch space** (status, priority, design notes) with zero history pollution.

Orchestrator usage (everything mechanical is in the `jj` skill):
- **Board = `jj tasks`** (or `jj tasks -r 'open_tasks()'`). Reconcile /
  reprioritize with `jj describe <id>` — a metadata edit, **not** a rebase.
- **Task ID = the change id** — there is no separate `#NN`; the change id *is*
  the handle. If you mirror into the Task tool, stash the change id in its
  `metadata` so the two stay linked. *Ready* = a task whose blockers (child-edges)
  are all done.
- **Dispatch** = hand the change id to the worker (or `jj edit <id>`); the worker
  fills the change in place, so its **design rationale becomes the commit body**.
  **Before dispatch, if the work tip has advanced past the task's parent, rebase
  the task onto it** (`jj rebase -r <id> -d <tip>`) so the worker builds on
  current code instead of stale filing-time provenance — this is what avoids
  conflicts and stops the working copy churning back to an old tree on every task
  switch (`jj` skill §8). Skip the rebase only when the task's files are disjoint
  from what landed. If rebasing is infeasible or impractical, dispatch the worker
  into a separate **workspace** (§5) instead — but its result must still be merged
  back onto the tip afterward, so that only **defers** integration, never avoids it.
- **Descriptions are a high-level decision record, not a transcript — `jj evolog`
  replays it.** Update a task's description only at **milestones** (a decision, a
  status change, a blocker), keep each entry terse, and **instruct task agents to
  do the same — not to dump their reasoning**. The point is that you (or the user)
  can skim a task and `jj evolog -r <id>` to inspect the work **at a glance**.
  evolog retains each revision, so the trail survives after the final description
  is trimmed to a clean implementation summary — serving natively, per task, the
  durable how/why that `JOURNAL.md` carries in files mode. Over-describing defeats
  the purpose; under a worker, the *commit body* holds detail, the task
  description stays skimmable.
- **Finish tasks; split to a child only on a meaningful boundary.** Default: keep
  an unfinished task `Task-Status: doing` and carry it to completion — and
  **verify it's actually fully done before marking `done`**, don't assume from a
  partial look. Spin the remainder into a **child task** (`jj new <worked-part>
  --no-edit -m "<remaining>" -m "Task-Status: todo"`) **only** when what's left is
  a genuinely separable unit worth tracking on its own — not as a way to offload
  an unfinished task. Used that way a real remainder is never a dropped thread;
  used for every partial it just fragments the board. For finer-grained steps
  that *shouldn't* be their own change, keep a `- [ ]` / `- [x]` checklist in the
  task description and tick it off via `jj describe` — `jj taskevo` then shows the
  steps completing over time, no extra tasks needed (`jj` skill §8).
- **Done** = set `Task-Status: done` (or drop the trailer so it leaves the board
  and becomes pushable); mark the Task-tool mirror `completed`. Before landing,
  rebase the task onto the current work tip and re-verify — catches any drift that
  landed *while the task was in flight* (the pre-dispatch rebase above handles
  drift up to dispatch; this is the final reconcile).
- **Land it onto `main` — this is not optional.** A done task is still a detached
  sibling until you **advance the mainline bookmark onto it**: `jj bookmark set
  main -r <id>`. That integrated change is now **the work tip** that the *next*
  task's pre-dispatch rebase targets — so the landed run accumulates as one clean
  advancing line instead of a fan of parallel done-siblings. Skipping this is the
  common failure: tasks read as "done" on the board but never make it onto main,
  the next rebase has no single tip to aim at, and the conflicts the pre-start
  rebase was meant to dodge come back. Land **each task as it completes**, then
  push when the run reaches a coherent point (`jj` skill §8).
- **Cross-machine hand-off**: push the `tasks` bookmark (octopus anchor, `jj`
  skill §8) `--allow-private` to a peer remote.

**Still in the description, not the graph:** ephemeral status (`doing` /
`blocked-on-user`) and priority — the DAG has no slot for "a worker is on this
*now*" or "P1 vs P2", and revsets don't sort by a description field. If a run
isn't jj-fluent, or the user wants the single-file glance, stay in `files` mode.

**Files in `jj` mode:** only `.orchestrate/config` is kept (it records
`backlog=jj` + the commit/verify settings). The **task graph replaces
`BACKLOG.md`**, and **`jj tasks` + `jj evolog` + `jj op log` replace
`JOURNAL.md`** — don't create or maintain those. A blocked-on-user task carries
`Task-Status: blocked` with the question in its description; keep `QUESTIONS.md`
only if you want a single async channel for the user to answer in.

---

## 3. The main loop

(In `backlog=jj` mode, read "BACKLOG.md" below as "the task graph" — the board is
`jj tasks`; reconcile = `jj describe` on task changes; "READY" = a task whose
blockers are all done; "mark Done" = set `Task-Status: done`. The loop shape is
identical.)

```
loop:
  reconcile BACKLOG.md (fold in new user input, re-sequence by priority + deps)
  pick the highest-priority READY task whose files don't collide with in-flight work
  if none ready:
      if blocked tasks remain -> they're all waiting on the user -> stop, summarize
      else -> backlog empty -> stop, summarize
  delegate it to a worker (§4); set its Task to in_progress + owner
  verify the result (§6)
  on success: worker has committed; mark Done in BACKLOG + Task completed, log it
  on failure: §7
  goto loop

(Keep BACKLOG.md and the Task-tool mirror in sync at each step — see §2.)
```

**Autonomy rules (these are the lessons from past runs — honor them):**
- **Do not stop while unblocked work remains.** Finishing a batch is not a
  reason to stop. Only the two exit conditions above end the loop.
- **Compact at every persistence boundary** (task captured / work committed /
  decision recorded), not at the context ceiling — then re-read durable state.
  See §2; this is what lets the loop run for hours without losing the plot.
- **Batch questions up front.** Before a long autonomous stretch, gather every
  design/scope decision the upcoming large tasks need and ask them in *one*
  `AskUserQuestion` with pre-baked options. Mid-run questions append to
  `QUESTIONS.md`; you keep working on other tasks rather than halting.
- **New user input mid-run** goes into `BACKLOG.md` with a priority and is
  sequenced — it does **not** preempt the current task unless the user flags it
  urgent.
- **Confirm scope, build the simplest correct thing.** Past runs churned on
  over-engineering ("make it simpler", "I don't need per-character mapping").
  When a task is ambiguous, prefer the simplest design that satisfies the goal
  and self-evaluate rather than gold-plating.

---

## 4. Delegating to workers

**Delegate whole tasks, not pre-spec'd edits.** Each task goes to a fresh worker
that owns it end-to-end: investigate the relevant code, decide the approach,
implement, verify, commit with `jj`, and report back. This is what keeps *your*
context thin — the expensive reading and grep-spelunking lives and dies inside
the disposable worker, not in the long-lived loop. Resist doing the
investigation yourself "to write a better spec": that is exactly what clobbered
past runs (one read `actions.ts` five times and `blockOps.ts` three times up
top). Do only **light scoping** — name the entry-point file(s) and the goal —
and let the worker do the deep read. Only true one-liners stay with you.

**Surface design decisions — don't let them vanish into the worker.** The user
wants to stay involved in design where it matters, and to know *how* changes
were made; that knowledge is what gets lost today. Pushing investigation into
the worker must not also bury the reasoning. So:
- If a task hits a **genuine design fork** the user would reasonably want a say
  in, the worker must **stop and report the fork** rather than silently picking.
  You route it to the user via `QUESTIONS.md` / a batched `AskUserQuestion`, and
  keep working other tasks meanwhile.
- For forks the worker *does* resolve on its own, it must report **what it chose,
  the alternatives, and why** — you record that in `JOURNAL.md` (§2) so the
  decision stays durable and reviewable instead of dying with the worker's
  context.

**Model tiering (cost-conscious, quality-preserving):** you cannot change your
own model mid-run, but you choose each worker's. Use a cheap model
(`opts.model: 'haiku'`/`'sonnet'`) for mechanical edits and read-only research;
reserve the strong model for genuinely hard or architectural tasks. When unsure,
keep quality — downshift only clearly-mechanical work.

**Token economics — where savings actually come from (and the trap).** "Tokens"
splits into **count** (text flowing) and **price** (tier × count); tier choice
changes price, not count. Spend the cheap path on the right axis:
- **Workers on `sonnet` = the real saving.** Workers are the token-*heavy*
  component (file reads, multi-turn edits, verifies); that bulk at ~5× cheaper
  tier is ~80% of the win. This is the lever — pull it.
- **Compact often = a separate real saving** on *your* side: the long-lived loop
  re-sends its context every turn, so compacting at each persistence boundary
  (§2) cuts re-sent input tokens at the expensive tier. Independent of worker tier.
- **Your own model tier barely matters** — a thin orchestrator is low-token, so a
  cheaper supervisor saves little absolutely. For a known execution-only run
  (backlog already decomposed, forks pre-decided), just launch the whole session
  on `sonnet`; don't expect much from it on a planning-heavy run.
- **Moving jj/commit/status churn into workers is ≈token-neutral** — those calls
  are tiny wherever they run. Do it for reliability/thinness (and to keep that
  churn at the worker's cheap tier), not as a token saver; don't oversell it.
- **The trap — granularity.** Every worker carries fixed overhead (system prompt +
  tool schemas + context re-read, a few k tokens before it does anything). Big
  tasks amortize it and win; **delegating tiny one-liners to a worker costs *more*
  than doing them inline** on the thin orchestrator. So delegate at *whole-task*
  granularity (the rule above), and if the backlog is mostly trivial one-liners,
  run the whole session on `sonnet` and do them inline rather than spawning a
  worker each. Net: the saving is **sonnet workers + compaction**, not the churn
  move — and it only holds if you don't mis-delegate.

**Parallel read-only investigation (encouraged).** Planning, code investigation,
and design scouting are read-only, so they **parallelize freely** — fan out
several investigators at once instead of reading serially yourself. Two
refinements make it cheap and reliable:
- **Cheap models by default.** Read-only scouting rarely needs the strong model;
  run these on `haiku`/`sonnet` and save the strong model for the actual design
  call or the edit. Reach for the cheap tier here whenever it makes sense — this
  is the clearest, lowest-risk win from model tiering.
- **A throwaway workspace to dodge in-flight churn.** If a worker mid-edit (or
  your own WIP `@`) would confuse a read-only agent, pin it to a consistent tree
  in a **temporary jj workspace**: `jj workspace add --revision <stable-rev>
  ../scout-N`, investigate there, then `jj workspace forget <name>` (and remove
  the dir). It's the *read-only* counterpart to the write-worker workspace rule
  in §5 — and much cheaper to reach for, since there's nothing to merge back and
  no file-collision risk. Encouraged whenever parallel investigation would
  otherwise trip over live changes.

**Worker prompt template:**
```
GOAL: <one self-contained outcome>
SCOPE: <entry-point file(s) + the goal; the worker investigates from here. Do
  NOT pre-spec exact edits — that's the worker's job, and reading it all
  yourself is what clobbers the orchestrator.>
CONSTRAINTS: <API to use, patterns to follow, what NOT to change>
QUALITY: prefer a well-structured solution and sound design over the smallest
  possible diff; self-evaluate your design choices.
DESIGN: if you hit a fork the user would reasonably want to decide, STOP and
  report it instead of guessing. For forks you resolve yourself, report the
  choice, the alternatives, and why.
VCS: this repo uses jujutsu (jj), NOT git. After the change verifies clean:
  - run `jj file track <path>` for any NEW file (repo has auto-track=none)
  - commit your task with `jj commit -m "<concise message>"`, ending the message
    with a trailer line `Task: #<backlogId>` so the commit is queryable per task
VERIFY before committing: <project verify command>. The build/typecheck EXIT 0
  is the only source of truth — IGNORE stale LSP diagnostics.
RETURN: a compact report — what changed (files + approach in 2-4 lines), the key
  design decision(s) + why, any unresolved fork, and the jj **change id**
  (`jj log -r @- --no-graph -T 'change_id.shortest(8)'`). Return the change id,
  NOT the git hash — the change id is stable across any later rebase/squash, the
  git hash is not. You are returning data to an orchestrator, not chatting.
```

Keep one self-contained task per worker. Name entry points so workers start in
the right place, but let them follow the code from there.

---

## 5. jj conventions

- **jj only.** Never `git commit` in a colocated repo — it caused detached-HEAD
  recoveries in past runs. All commit/branch/rebase ops go through jj.
- **New files must be tracked.** With `snapshot.auto-track=none()`, new files are
  silently untracked and break CI. Every file-creating worker runs
  `jj file track <path>`.
- **Working model — amend changes in place, don't stack fixups.** The working
  copy is itself a change (`@`) and edits are snapshotted automatically (no
  `git add`). Update the *relevant* change rather than appending "fix typo"
  commits:
  - **Current change (`@`):** edit freely; set/refine the message with
    `jj describe -m "…"`. Start the next change with `jj new` — or `jj commit -m
    "…"`, which is `describe` + `new` in one.
  - **An earlier unpushed change:** either `jj edit <id>` to make it the working
    copy and edit it directly (descendants auto-rebase), then `jj new` /
    `jj edit <tip>` to resume; **or** make the fix in `@` and fold it back with
    `jj squash --into <id>` (plain `jj squash` folds `@` into its parent).
  - **Fixups spanning several ancestors:** `jj absorb` auto-routes each hunk in
    `@` into the ancestor change that last touched those lines — ideal for
    review cleanups.
  - **Other tools:** `jj split` divides one change in two, `jj abandon` drops
    one, `jj describe -r <id>` rewords any change. Conflicts are recorded in the
    commit (non-blocking) and can be resolved later.
  - Squash WIP/fixups before pushing so **every change is coherent and
    compiles**.
- **Pushing goes through bookmarks** (named pointers ≈ git branches):
  `jj bookmark set <name> -r @-` then `jj git push`. Don't rewrite
  already-pushed/immutable changes (jj warns) — stack a new change on top
  instead.
- **Commit ownership: workers commit their own task** (per `config`). You verify;
  you don't re-commit their work.
- **Releases** (when asked): bump CHANGELOG → `jj commit` → `jj bookmark set main
  -r @-` → `jj tag set vX -r @-` → push.

**Tasks ↔ jj changes — what to lean on, what to avoid.** jj gives you two things
worth using as durable task infrastructure, and one tempting trap:
- **Change IDs are stable task handles.** A jj *change id* (e.g. `qpvuntsm`;
  `jj log -T change_id`, `.shortest(8)` for a prefix) survives amend / rebase /
  squash; the git commit hash does **not**. Record the **change id** for
  dispatched and Done tasks in `BACKLOG.md` and `JOURNAL.md`, never the git hash
  — the hash goes stale the moment the change is rebased or squashed.
- **The history is queryable per task.** Workers end each commit message with a
  `Task: #<id>` trailer, so `jj log -r 'description(substring:"Task: #42")'`
  confirms a task actually landed and prints its change id. Use this to **verify
  Done from jj** instead of trusting the worker's self-reported id — it closes
  the gap where a worker reports a commit that isn't really there.
- **Empty changes as the queue — only under discipline.** A change per task with
  `jj log` as the board is viable, but **only** in the exact form `backlog=jj`
  prescribes (§2): tasks **siblings off the base, off-main, unpushed**, with
  priority/status in the **description**. Get any of that wrong and it turns
  fragile — *stacked* empties invent false dependencies; encoding *priority as
  graph position* makes every reprioritization a `jj rebase`; doing it *on a
  pushed branch* means immutable changes you can't restatus and polluted history.
  The cost of the disciplined version is **not** performance (tens of empty
  changes are free) — it's the jj fluency and the mandatory `tasks()` revset. The
  default `backlog=files` exists because reprioritizing is an O(1) text edit and
  the file survives `/compact` with no jj knowledge. Either way, jj owns
  **identity and proof of what landed**.

**Parallelism & workspaces:**
- Default to **sequential** dispatch. Workspaces are usually overkill.
- Only run workers in parallel when their **file sets are disjoint** — overlapping
  files (e.g. two tasks both editing `App.tsx`) must be serialized.
- Use a separate **jj workspace per parallel worker** only when the user asks for
  parallel work or it's clearly worth it. After any cross-workspace
  rebase/squash, **always run the full typecheck + build**: jj's auto-merge is
  textual, not semantic — a clean (no-conflict) rebase can still be broken (a
  past run silently broke a rename this way).

---

## 6. Verification gate

A task is not Done until it passes the gate. Default **self-verify** (per
`config`): the worker runs the project's verify command and commits only on
EXIT 0; you then spot-check before marking Done.

**Keep the spot-check light** — read the worker's reported decisions and
confirm the verify exit code (re-running the typecheck yourself is cheap; its
output is just an exit code). Only pull the actual diff when the worker's report
raises a flag, the task was important, or the design decision warrants your eyes.
Re-reading every file the worker touched would re-clobber the context the §4
boundary just protected — don't.

For **complex or especially important tasks**, offer to switch to an
**independent reviewer**: spawn a fresh subagent that runs the gate and reviews
the diff before you mark Done — the writer is not the only checker. Record the
mode in `config` if the user wants it as the default.

The exact verify command is **project-specific** — discover it from `CLAUDE.md`
and package scripts (typecheck per package, build, any smoke/round-trip scripts).
Treat the build/typecheck **exit code** as the source of truth, not editor/LSP
diagnostics.

---

## 7. Failure & blockers

- Worker fails or returns a broken tree → first try to **root-cause and fix**
  (yourself or by re-delegating with the diagnosis added). A broken working copy
  is top priority — get it compiling before anything else.
- Still stuck after one refocused retry → mark the task **Blocked** in
  `BACKLOG.md` with the reason, append the question to `QUESTIONS.md`, and
  **continue with other ready tasks**. Do not let one blocker stall the run.

---

## 8. Project-specific notes

Per-project verify commands, known footguns, and conventions belong in that
project's `CLAUDE.md`, not here. When you discover a recurring trap (e.g. a
literal U+2029 paragraph-separator must be written ` `; NFC/NFD filename
mismatches; a specific smoke-test command), write it to the project's
`CLAUDE.md` so future runs and workers inherit it.

---

## 9. Workflow conventions (carry across every run)

Cross-project preferences for this workflow — distinct from §8's per-project notes:

- **Done tasks drop the trailer.** When a `backlog=jj` task is finished, REMOVE its
  `Task-Status:` / `Priority:` trailer entirely (a clean, pushable commit that leaves
  the board) rather than setting `Task-Status: done`. Strip it retroactively too when
  cleaning a stack of already-done tasks.

- **Squash small fixes into their feature — only when clean.** A small fix to a feature
  already in the unpushed stack should fold into that feature's change
  (`jj squash --from <fix> --into <feature> --use-destination-message` — the bare form
  opens an editor that fails with no TTY). Do it ONLY when it applies cleanly / is worth
  it; if it would need resolving more than a trivial conflict, leave it as a standalone
  fixup commit. Avoid `jj absorb` when an intervening change rewrote the same file (it
  conflicts) — squash into the most-recent toucher instead. If a squash goes wrong,
  `jj op restore <snapshot-before-it>` (the op log shows a `snapshot working copy` right
  before the bad op).

- **Compaction — preserve only the spine.** You cannot self-invoke `/compact`. When
  compaction runs, DISCARD raw tool output, file reads/diffs, worker transcripts, and
  resolved back-and-forth; PRESERVE only the jj task board (open change-ids + one-line
  goals), the work-tip / `main` change-id, in-flight worker ids + what each is doing, and
  unresolved user decisions. Re-derive the rest from `jj tasks` / `jj log` / memory.

- **Proactively prompt for `/compact`.** Since you can't trigger it, REMIND the user to
  run `/compact` (or the cheaper `/rewind`) at natural boundaries — after a task lands or
  a batch is persisted and context has grown — whenever it would actually help. Don't nag
  every turn; flag it when useful.

- **Reuse a warm worker for a run of small fixes.** Per-worker spin-up (system prompt +
  tool schemas + CLAUDE.md/ARCHITECTURE read) is fixed overhead. For several small fixes
  arriving one at a time, prefer continuing ONE background worker via SendMessage (warm
  codebase context, no re-read) or batching them into a single dispatch, rather than a
  fresh worker each. Keep one-self-contained-task-per-worker for substantial or unrelated
  work, and don't let a reused worker's context balloon across many fixes.
