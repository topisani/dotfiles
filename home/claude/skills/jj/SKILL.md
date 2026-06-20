---
name: jj
description: >-
  Jujutsu (jj) version-control fluency + the change-based task tracker. Use when
  doing NON-TRIVIAL jj work — rebase / squash / split / absorb, resolving
  conflicts, bookmarks & pushing, the immutable/private boundary, workspaces,
  operation-log undo/recovery, or the `jj tasks` workflow (tracking work as jj
  changes). NOT needed for a plain `jj commit` / `jj describe` (that reflex is
  already known). The repo here is jj-colocated with git; never `git commit`.
---

# Jujutsu (jj)

Opinionated reference for working in jj. The everyday `jj commit` / `jj describe`
loop is assumed; this is for the operations that actually have sharp edges, plus
the **jj-tasks** system (§8) that tracks work as commits.

Version here: jj 0.42, colocated with git. Authoritative for anything
version-specific: `jj <cmd> --help` and `jj config list`. Docs: https://docs.jj-vcs.dev/latest/

## 1. Mental model

- **The working copy is a commit.** `@` is a real change; edits are
  **auto-snapshotted** into it on every command — there is no staging, no
  `git add`. (This repo sets `snapshot.auto-track=none()`, so *new* files are the
  one exception: `jj file track <path>` or they're never snapshotted — and CI
  fails on the missing file.)
- **Change id ≠ commit hash.** Every change has a stable **change id** (e.g.
  `qtouzqsv`, 8-char prefix via `.shortest(8)`) that **survives amend / rebase /
  squash**. The git commit hash changes on every rewrite. **Always refer to and
  record change ids**, never hashes — a hash goes stale the moment the change is
  touched. Change ids are written into the git commit header
  (`git.write-change-id-header=true`, default), so they even survive push/fetch
  to another machine.
- **History is meant to be rewritten.** Amend in place; don't stack "fix typo"
  commits. Descendants auto-rebase when you edit an ancestor.
- **Operations are journaled.** Every command is one entry in `jj op log` and is
  undoable (§8). This is the safety net that makes fearless rewriting fine.

## 2. Everyday rewriting — amend in place, don't stack fixups

- **Current change (`@`):** edit files freely; set the message with
  `jj describe -m "…"`. Start the next with `jj new` (or `jj commit -m "…"` =
  describe + new).
- **An earlier unpushed change:** `jj edit <id>` makes it `@` and you edit it
  directly (descendants auto-rebase); or fix in `@` and fold back with
  `jj squash --into <id>` (plain `jj squash` folds `@` into its parent).
- **Fixups spanning several ancestors:** `jj absorb` auto-routes each hunk in `@`
  into the ancestor that last touched those lines. Ideal after a review pass.
- **Reshape:** `jj split` divides a change; `jj abandon` drops one;
  `jj duplicate` copies; `jj parallelize` turns a linear chain into siblings;
  `jj rebase -r <c> -d <new-parent>` moves one change, `-s` moves it + its
  descendants, **repeated `-d` makes a merge** (`-d A -d B` → parents {A,B}).
- `jj describe -r <id>` rewords any change. Squash WIP before pushing so every
  pushed change compiles and is coherent.

## 3. Inspecting — revsets & templates

- **Revsets** select commits (`jj help -k revsets`). Workhorses: `@`, `@-`
  (parent), `x::y` (range), `::x` (ancestors), `x..` (descendants-ish),
  `roots()`, `heads()`, `descendants()`, `trunk()`, `mutable()` / `immutable()`,
  `empty()`, `description(substring:"…")`, `bookmarks()`, `tags()`,
  `present(x)` (→ `none()` if `x` doesn't resolve — safe in config). `~` is set
  difference, `|`/`&` union/intersection.
- **Revset aliases** (config `[revset-aliases]`) define named/parameterized sets:
  `'tasks()' = '…'`. **Names must be valid identifiers** — no hyphens
  (`open_tasks` ✓, `open-tasks` ✗).
- **Templates** format output (`jj log -T '<template>'`, `jj help -k templates`).
  Native **git-trailer** support is the clean way to read structured metadata
  from descriptions: `trailers.contains_key("Priority")` (Boolean),
  `trailers.filter(|t| t.key()=="Priority").map(|t| t.value()).join("")`. A bare
  string is **not** a Boolean — guard `if(...)` with `contains_key`, not the
  value. Template aliases live in `[template-aliases]`.
- **Command aliases** (`[aliases]`) only **prepend args to ONE subcommand** and
  forward trailing args — they cannot chain commands. The escape hatch for
  multi-step is `jj util exec -- <program>`. (Note: command aliases load **only**
  from real config files, never `--config`/`--config-file` — so test them by
  installing them, not via a throwaway file. Revset/template aliases *do* load
  from `--config-file`, so validate those against a temp file first.)

## 4. Bookmarks, pushing & the boundaries

- **Bookmarks** are named pointers (≈ git branches): `jj bookmark create <name>
  -r <rev>` / `jj bookmark set <name> -r <rev>` (`-B` to move backwards).
- **Push** goes through bookmarks: `jj bookmark set <name> -r @-` then
  `jj git push`. Push one to a specific remote: `jj git push --bookmark <name>
  --remote <r>`. `jj git push -r <revset>` pushes bookmarks **already on** those
  commits — it does **not** auto-create them; only `-c/--change` auto-names a
  bookmark (`templates.git_push_bookmark`, default `push-<changeid>`).
- **Immutable boundary:** don't rewrite pushed/immutable changes (`trunk()`,
  tags, untracked remote bookmarks) — jj refuses. Stack a new change instead.
- **Private boundary:** `git.private-commits` (a revset) marks commits jj
  **refuses to push to any remote**, and a private commit **blocks its
  descendants** from pushing too. Override per-push with `--allow-private`. (Here
  it covers `private:*`-described commits and **empty** task placeholders
  (`tasks() & empty()`) — todo stubs and the transport anchor; a finished task
  that holds real code is non-empty and stays pushable. See §9.)

## 5. Conflicts

Conflicts are **recorded in the commit, not blocking** — a rebase/merge always
completes; conflicted files carry markers and the commit is flagged conflicted.
Resolve later with `jj resolve` (or edit + describe), at your own pace. This is
why rebasing a stack is safe even when something mid-stack conflicts.

## 6. Workspaces — parallel working copies

Multiple working-copy dirs sharing **one repo** (one op store, one set of
commits/bookmarks). Each has its **own `@`**. Use to work a task in isolation
without cloning, or to run parallel agents on disjoint changes.
- `jj workspace add [--revision <rev>] <path> [name]` — new working copy.
- `jj workspace list` / `jj workspace forget [name]` / `jj workspace root`.
- **Gotcha:** when an op in workspace A rewrites workspace B's `@`, B's on-disk
  copy goes **stale** — run `jj workspace update-stale` in B before working there.
- After any cross-workspace rebase/squash, **re-run the full typecheck + build**:
  jj's auto-merge is **textual, not semantic** — a clean (no-conflict) merge can
  still be broken (a rename applied on the other side, etc.).

## 7. Recovery — the operation log (jj's superpower)

Nothing is lost; every command is reversible.
- `jj op log` — every operation with an id.
- `jj undo` — invert the **last** operation only (in jj 0.42 it takes **no op
  argument**; to reach back further use `jj op restore`).
- `jj op restore <op>` — hard-reset the **entire repo** (commits, bookmarks,
  working copy) to how it was at that operation. Destructive to everything since,
  so prefer narrower moves when other work has happened since the mistake.
- `jj op diff --from <op> --to @` — see what an op (or range) changed before
  acting.
- `jj evolog -r <id>` — how one change evolved across its own rewrites.
- **Revive one abandoned change** (without rewinding everything): an abandoned
  commit still exists in the store — `jj duplicate <commit-id>` brings its content
  back as a fresh visible change (new change id). Find the commit id in
  `jj op show <abandon-op>` / `jj op log`.

Recipe: messed up the last thing → `jj op log` → `jj undo`. Need to jump back
past several ops → `jj op restore <good-op>` (inspect first with `jj op diff`).
Accidentally abandoned just one change while later work is fine → `jj duplicate`.

## 8. jj-tasks — tracking work as changes

A general, repo-agnostic task tracker built on jj (wired in **global**
`~/.config/jj/config.toml`; the orchestrate skill's `backlog=jj` mode uses it).
The queue lives in the commit graph, not a file — so tasks carry **design-time
provenance** (the parent pins the code state when the task was filed), **native
blockers** (DAG edges), and **stable ids** (the change id).

**What a task is:** any commit carrying a `Task-Status:` trailer. By convention,
off-main and unpushed, parented on `@` (or the current work tip) so its parent
records the state it was designed against. Trailers:
```
Task-Status: todo        # todo | ready | doing | investigating | blocked | done
Priority: P2             # optional
Scope: path/a, path/b    # optional pointer for whoever picks it up
```
The **change id is the task id** — stable across rewrites and portable across
machines (written into the git commit header). Don't invent a separate numbering
(`#42`) — there's nothing to cross-reference; the change id *is* the handle.

**The wiring** (already in global config — don't redefine per-repo):
- `[revset-aliases]`: `'tasks()'` = commits with a `Task-Status:` trailer;
  `'task_board()'` = tasks minus the transport anchor (what `jj tasks` shows);
  `'open_tasks()'` = `task_board()` minus `Task-Status: done` (so it also drops
  the anchor).
- `[revsets] log` wraps the builtin default with `~ (tasks() & empty())` → only
  **empty** task placeholders (todo stubs, the transport anchor) are **hidden from
  `jj log`** (view them with `jj tasks`). The moment you `jj edit` a task and write
  real code it's non-empty, so it shows in the log like any other change — even
  while it still carries its `Task-Status:` trailer. (Keying on bare `tasks()`
  instead would hide every finished/worked task too, `@` included.)
- `[git] private-commits` includes `tasks() & empty()` → empty placeholders +
  anchor are **never pushed by default**; a finished task holding real code is
  non-empty and stays pushable so you can land it onto main. (Bare `tasks()` here
  would block every finished task from pushing, since it keeps its trailer.)
- `[aliases]`: `tasks` (the board), `todo` (create one), `taskevo` (a task's
  evolution / decision trail) — `todo`/`taskevo` are `jj util exec` wrappers, the
  only way to script a multi-step or positional-arg alias.
- `[template-aliases]`: `task_log` (the one-line board format used by `jj tasks`
  — id · status · `(priority)` · summary · `(needs <id…>)` blocker suffix; also
  usable via `jj log -T task_log`), `task_field(key)` (read a trailer value),
  `task_draft` (the `jj todo` editor buffer), `taskevo` (a `\x1f`/`\x1e`-delimited
  per-step **record** — id, time, empty, description — that the `jj taskevo` wrapper
  parses into the chronological description trail, not a human-facing line).
- `[colors]`: `task_todo`/`task_blocked`/`task_doing`/`task_done`/`task_epic`
  (status tags), `task_priority` (the `(Px)` tag), `task_done_dim` (done summary),
  `task_needs` (the `(needs …)` suffix) — change these to recolor the board.

**Commands:**
- **View the board:** `jj tasks` (all) · `jj tasks -r 'open_tasks()'` (open only);
  args forward to the inner `jj log`. It's a plain `jj log -r task_board() -T
  task_log --no-graph --reversed` — a flat, oldest-first list, one `task_log` line
  per task. Dependencies are shown **textually** by task_log's `(needs <id…>)`
  suffix (naming each task's blockers — its task-parents — by change id), not by
  nesting; jj's native graph is avoided because it draws no connector for a
  *linear* blocker chain (A needs B needs C looks like three unrelated roots).
  The transport anchor is excluded (via `task_board()`).
- **Add a task:** `jj todo "<summary>"` creates one off `@` with `Task-Status:
  todo`; bare **`jj todo`** opens your editor (seeded with the marker plus
  commented-out `Priority:`/`Scope:` help, and self-discards if you save no
  summary). Explicit form: `jj new @ --no-edit -m "<summary>" -m "Task-Status:
  todo
  Priority: P2"` — `--no-edit` keeps your working copy put; the second `-m` is
  the trailer block.
- **Replan / reprioritize:** `jj describe <id>` and edit the trailers — **no
  rebase**, because priority/status are metadata, not graph position.
- **The description is a curated decision record; `jj evolog` replays it.**
  Update a task's description at **meaningful checkpoints** — a decision taken, a
  status change, a blocker hit — **not** every step, and keep each revision
  **terse and high-level** (the decision and why, not a play-by-play). Every
  `jj describe` is an evolution step — **`jj taskevo <id>`** replays the trail (or
  raw `jj evolog -r <id> -p`). It renders the **description trail** in chronological
  order — one row per checkpoint (a distinct consecutive description, trailing
  whitespace ignored so rebase artifacts merge) — then ends with the task's single
  real code change via `jj diff -r <task>`. The first checkpoint prints the full
  description; each later one shows a **`delta` word-diff of the description**
  against the previous checkpoint (so you read just what changed in the prose).
  It deliberately shows **no per-checkpoint code diffs**: on a heavily-rebased or
  tangled evolog (two stacked changes interleaved in one change's history) no
  per-step method is reliable — `interdiff` between divergent-parent states shows
  whole features, and cumulative or summed `inter_diff`s count transient/split-out
  edits. The description trail is the dependable signal; the code change is shown
  once at the end. It reads as a **skimmable history of the work**,
  and the **final**
  description trims to a clean implementation summary. The goal is
  inspection-at-a-glance — **not a chat transcript**; don't dump reasoning in.
- **Block on another task:** make it a child — `jj new <blocker> --no-edit -m …`;
  blocked by several = a merge — `jj new <A> <B> --no-edit -m …`. When a blocker
  lands, dependents auto-rebase. *Ready* = a task whose blockers are all done.
- **Before starting, rebase onto the current work tip if it has moved on.** A
  task's parent pins the state it was *filed* against (provenance), but
  `jj edit <id>` then resets the working copy back to that — by-now possibly
  **stale** — tree, so you fight conflicts against since-landed work and the
  on-disk tree churns every time you switch between the task and mainline. Rebase
  first — `jj rebase -r <id> -d <work-tip>` — so the task builds on current code
  and the working copy stays put (conflicts are recorded, **non-blocking** —
  resolve them once, up front; the original provenance survives in `jj evolog`).
  Skip the rebase only when the task is genuinely **disjoint** from what landed
  (no shared files) — then there's nothing to conflict and nothing to switch.
  **When rebasing is infeasible or impractical** (the task must stay based on its
  original state, or the rebase would be a mess to untangle), work it in a
  separate **workspace** (§6) instead — `jj workspace add --revision <id>
  ../<name>` — so its tree is isolated and mainline doesn't churn. But the result
  still has to be **merged/rebased back** onto the work tip eventually, so a
  workspace only **defers** the integration, it never avoids it.
- **Start work:** `jj edit <id>`, do the work; the design rationale in the
  description becomes the commit body. The moment the change holds real code it's
  non-empty, so it's already out of the hidden/private placeholder set — visible
  in `jj log` and pushable. **Finish** by setting `Task-Status: done` (it stays on
  the `jj tasks` board, dimmed, as a record); **remove the trailer entirely** if
  you'd rather it leave the board for good.
- **Land it onto main — finishing ≠ integrating.** A finished task is pushable but
  still a detached sibling off its base. **Advance your mainline bookmark onto the finished change** —
  `jj bookmark set main -r <id>` — so the work actually integrates into the
  shipped line and *becomes the new work tip the next task rebases onto*. Land
  each task as it completes; if you let done tasks pile up unlanded, they stay
  parallel siblings, the "work tip" the next rebase targets is ambiguous, and you
  re-inherit the very conflicts the pre-start rebase was meant to avoid. (If the
  task was worked in a **workspace** (§6), this is also where its result rebases
  back onto the tip.) Push when ready: `jj git push` once main carries the landed
  run.
- **Meaningful split → child task; otherwise just keep working.** Spin the
  remainder into a child task (`jj new <worked-part> --no-edit -m "<remaining>"
  -m "Task-Status: todo"`) **only when it's a genuinely separable unit of work**
  worth tracking on its own. For an ordinary not-yet-finished task, **don't
  split** — leave it `Task-Status: doing` and carry it to completion; set `done`
  only once it's **fully** complete (verify, don't assume). The child-task move
  exists so a real remainder isn't lost — not as a reason to fragment one task
  into many. (Same up front: carve a big task into child tasks only when the
  sections are independently meaningful.)
- **In-task steps → markdown checkboxes, not child tasks.** For sub-steps that
  don't warrant their own change, keep a `- [ ]` / `- [x]` checklist *in the task
  description* and tick items off with `jj describe` as you go. They ride along in
  the description, and `jj taskevo` shows the checklist filling in over time — so
  step-level progress is visible and tracked without fragmenting the board.
  Reserve child tasks for genuinely separable work; use checkboxes for everything
  finer-grained.
- **Split issue into a workspace** (§6): `jj workspace add --revision <task-id>
  ../<name>` to work it in an isolated checkout.

**Sync tasks to another machine** (transport anchor — copy tasks without pushing
to the shared remote):
- Keep a `tasks` bookmark on an **octopus** merge of the open tasks:
  `jj new <t1> <t2> <t3> --no-edit -m "tasks anchor" -m "Task-Status: anchor"`
  then `jj bookmark set tasks -r <anchor>`. Rebuild when the set changes:
  `jj rebase -r tasks -d <t1> -d <t2> …` (repeated `-d` resets its parents).
- `jj git remote add <machine> <url>` once, then
  `jj git push --bookmark tasks --remote <machine> --allow-private`. The other
  machine `jj git fetch --remote <machine>`; change ids match on both sides.
- **Caveat:** the anchor descends from its tasks' base, so pushing it also
  carries any **unpushed ancestors** (your current work). That's usually
  desirable (sync the whole context); for *tasks-only* transport, base tasks on a
  pushed commit (e.g. `trunk()`) instead of `@`.

## 9. Footguns (jj-specific)

- **Never `git commit` in this colocated repo** — it leaves a detached HEAD jj
  doesn't track. All commit/branch/rebase ops go through jj.
- **New files aren't tracked** (`auto-track=none()`): `jj file track <path>` or
  they vanish from the commit and break CI.
- **Don't rewrite pushed/immutable changes** — stack on top.
- **Cross-workspace auto-merge is textual, not semantic** — always re-verify
  (typecheck + build) after a cross-workspace rebase/squash.
- **Revset/template alias names are identifiers** — no hyphens.
- Project-specific traps (verify commands, the `-0.00` round-trip quirk, literal
  `U+2029`) live in that project's `CLAUDE.md`, not here.
