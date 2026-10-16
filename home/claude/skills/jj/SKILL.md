---
name: jj
description: Perform version-control operations with Jujutsu (jj) instead of git. Use whenever the user mentions jj, jujutsu, change IDs, the operation log, or asks to commit, push, branch, rebase, stash, revert, or undo anything in a repo where `jj st` works — including colocated repos where both git and jj are present. Prefer jj over git for all VCS work in such repos, and never run state-mutating git commands there.
---

# jj instead of git

Jujutsu (jj) is a Git-compatible VCS. It reads and writes the same repos as git,
but has a different, safer mental model. When a repo is jj-managed, do all VCS
operations through `jj` — mixing mutating git commands (`git commit`, `checkout`,
`reset`, `merge`, `rebase`, `stash`) into a jj repo corrupts jj's view of HEAD
and causes confusing divergence. Read-only git commands are safe but jj equivalents
are preferred.

**Detect a jj repo:** run `jj st`. If it succeeds, use jj. A colocated repo has a
normal-looking `.git/` directory but is still driven by jj.

## The mental model (why jj behaves differently)

1. **No staging area.** Every edit in the working copy is instantly part of the
   working-copy commit. There is no `git add` — never look for one.
2. **The working copy IS a commit.** `@` is the working-copy commit; `@-` is its
   parent. Editing files amends `@` automatically on the next jj command. "Done
   editing" means `jj new` (or `jj commit`), not `git add`/`git commit`.
3. **Changes outlive commits.** Every change has a stable **change ID** (e.g.
   `kntqzsqt`) that survives every rewrite, plus a volatile commit ID (the git
   hash). Always reference work by change ID — commit IDs change after every amend
   or rebase.
4. **Everything is undoable.** Every command is recorded in the operation log.
   `jj undo` reverses the last operation; `jj op log` lists them;
   `jj restore` reverts file content. Abandoning or losing work is recoverable —
   this makes jj safe to operate aggressively, but still check `jj log` before
   bulk operations.
5. **Conflicts are data, not blockers.** Operations (rebase, merge) never stop
   halfway because of conflicts; conflicted commits are marked `(conflict)` and
   can still be built on. Resolve when convenient with `jj resolve` or by editing
   conflict markers, then `jj squash` the fix into the conflicted commit.
6. **Push is explicit.** `jj git push` only pushes bookmarks you moved/created
   deliberately. Fetching never silently changes local bookmarks.

## Git → jj cheat sheet

| Task | git | jj |
|---|---|---|
| Status | `git status` | `jj st` |
| Diff of current change | `git diff HEAD` | `jj diff` |
| Diff of another change | `git diff X^ X` | `jj diff -r X` |
| Diff A→B | `git diff A B` | `jj diff --from A --to B` |
| Show a change | `git show X` | `jj show X` |
| Add/remove files | `git add` / `git rm` | just create / `rm` the files |
| Untrack a file | `git rm --cached F` | `jj file untrack F` (must be gitignored) |
| Commit & start new change | `git commit -a` | `jj commit -m "msg"` |
| Set/edit message of @ | `git commit --amend` | `jj describe -m "msg"` |
| Edit message of any change | `git commit --fixup=reword:X` | `jj describe X -m "msg"` |
| Amend current change | `git commit --amend` | edit files (auto-amends @) |
| Finish change, start new one | `git commit` | `jj new` |
| Squash @ into parent | `git commit --amend -a` | `jj squash` |
| Squash only some paths | `git add -p` | `jj squash <paths...>` (filesets) |
| Move @'s diff into ancestor X | `git commit --fixup=X` + autosquash | `jj squash --into X` |
| Split working copy into 2 changes | `git commit -p` | `jj split` (interactive — see agent rules) |
| Stash | `git stash` | `jj new @-` (old @ stays as sibling; restore with `jj edit <old @>`) |
| Start topic branch | `git switch -c topic main` | `jj new main` (+ later `jj bookmark create topic`) |
| Switch to a branch to work on it | `git switch topic` | `jj edit <topic change>` or `jj new topic` |
| Merge A into current | `git merge A` | `jj new @ A` |
| Rebase change X onto B | `git rebase --onto B X^` | `jj rebase -s X -o B` |
| Move bookmark A onto B | `git rebase B A` | `jj rebase -b A -o B` |
| Reorder commits | `git rebase -i` | `jj rebase -r C --before B` (or `jj arrange`) |
| Cherry-pick | `git cherry-pick X` | `jj duplicate X -o <dest>` |
| Revert a change | `git revert X` | `jj revert -r X -B @` |
| Discard working-copy edits | `git restore <paths>` | `jj restore <paths>` |
| Make current change empty | `git reset --hard` | `jj restore` |
| Drop current change | `git reset --hard HEAD~` (lossy) | `jj abandon` (undoable) |
| Drop parent, keep its diff in @ | `git reset --soft HEAD~` | `jj squash --from @-` |
| List branches | `git branch` | `jj bookmark list` |
| Create branch | `git branch N X` | `jj bookmark create N -r X` |
| Move branch | `git branch -f N X` | `jj bookmark move N --to X` (add `--allow-backwards` to go back) |
| Delete branch | `git branch -d N` | `jj bookmark delete N` |
| Tags | `git tag` | `jj tag list / set / delete` |
| Fetch | `git fetch` | `jj git fetch` |
| Push branch | `git push origin topic` | `jj git push -b topic` |
| Push current change as new branch | `git push -u origin topic` | `jj git push -c @-` (creates+pushes bookmark) |
| Log | `git log --oneline --graph` | `jj log` (see revsets below) |
| Grep tracked files | `git grep foo` | `rg foo` (jj working copy is plain files) |
| Blame | `git blame F` | `jj file annotate F` |
| Repo root | `git rev-parse --show-toplevel` | `jj workspace root` |
| Undo | *(nothing)* | `jj undo` |
| History of repo states | *(nothing)* | `jj op log`, `jj op restore <op>` |

## Session workflow (always follow this)

Start every work session by creating a fresh change with a working description, so
edits are never sitting in an undescribed change and the repo is always in a clean
checkpointable state:

```bash
# 1. At session start: new change with a tentative description
jj new -m "wip: <what I'm about to do>"
# ... edit files; every jj command auto-snapshots them into @ ...

# 2. When done: set the final description and leave an empty change on top
jj describe -m "final: <what was done>"   # or just `jj commit -m "final msg"`
jj new                                    # (skip if you used `jj commit`)
```

End-of-session invariant: the top change is empty and described, and all the
session's work sits in described commits below it. `jj commit -m "..."` does
describe+new in one step; `jj describe` + `jj new` is equivalent if you prefer
to set the message first. If the session's work belongs on a branch, create/move
a bookmark before finishing (see below).

## Core workflows

### Start feature work
```bash
jj new trunk() -m "implement widget"   # new change on top of trunk
# ... edit files; every jj command auto-snapshots them into @ ...
jj st                              # verify what changed
```

### Finish and push a new branch
```bash
jj commit -m "implement widget"          # lock in @, start fresh change
jj bookmark create feature/widget -r @-  # name the finished change
jj git push -b feature/widget
```
Or in one step: `jj git push -c @-` (pushes the finished change under a
bookmark; with `git.push-bookmark-prefix` configured the name is automatic).

### Address review comments on an already-pushed change
```bash
jj edit <change-id>       # work directly in that change
# edit files → auto-amends it; descendants auto-rebase
jj git push              # bookmark moved → push updates the PR
```
This is jj's killer feature: no fixup commits, no interactive rebase.

### Resolve a conflict (e.g. after rebase onto moved trunk)
```bash
jj rebase -s <change> -o main@origin
# conflict recorded, nothing is "interrupted"
jj new <conflicted-change>
# edit the file: jj conflict markers show both sides; write the resolution
jj diff                  # review
jj squash                # resolution lands in the conflicted commit
```
`jj resolve <path>` opens a 3-way tool if one is configured; editing markers +
squash always works and is better for non-interactive use.

### Undo
```bash
jj undo                  # reverse the last operation
jj op log                # find an older state
jj op restore <op-id>    # travel back to that point
```
Prefer `jj undo` over trying to manually reverse a mistake.

## Agent rules (non-interactive use)

jj's defaults assume a human with `$EDITOR`. In an agent context:

- **Always pass messages inline**: `jj describe -m "..."`, `jj commit -m "..."`,
  `jj new -m "..."`. Bare `jj describe`/`jj commit` will try to open an editor
  and hang.
- **Avoid interactive diff editors**: `jj squash -i`, `jj split`, `jj diffedit`,
  `jj resolve` (tool-based) all open TUIs. Non-interactive equivalents:
  - partial squash by path: `jj squash <fileset>` (e.g. `jj squash src/a.py docs/`)
  - move whole changes: `jj squash --from X --into Y`
  - rewrite a commit's content without checkout: not possible headless — instead
    `jj edit X`, modify files with edit tools, `jj new` when done.
- **Prefer change IDs** in every command argument; never hardcode commit IDs from
  earlier output (they go stale after any rewrite).
- **Verify after mutating**: run `jj st` (or `jj log -r '::@ & visible_heads()'`)
  after each structural change to confirm the graph looks right.
- **Don't push blindly**: check `jj log` first; `jj git push` refuses ambiguous
  situations (divergent bookmarks, missing remote-tracking) — read its error and
  fix the bookmark state rather than forcing.
- **Divergent changes** (same change ID, two commit IDs, usually after a fetch):
  pick one with `jj rebase` / `jj abandon`, or `jj metaedit` to rebase your side
  onto the remote's. Never `git push --force` to "fix" it.
- **Trunk sync**: `jj git fetch --trunk main` (or a `trunk()` revset alias)
  keeps the local `main` bookmark fast-forwarding with the remote; plain
  `jj git fetch` only updates `main@origin`.

## Log & revsets (the `git log` replacement)

`jj log` shows a graph with change ID, author, date, commit ID. Default view is
"your work + context"; if commits seem missing, widen the revset:

```bash
jj log -r 'all()'          # everything reachable
jj log -r '::@'            # ancestors of working copy
jj log -r '@ | @- | @--'  # working copy and two parents back
jj log -r 'author(me)'    # my changes
jj log -r 'description(widget)'   # message search
jj log -r 'files(src/auth/)'      # changes touching a path
jj log -r 'mine() & ~description(empty())'
```

Set operators: `x-` parents, `x+` children, `::x` ancestors, `x::` descendants,
`x::y` DAG range (ancestry path), `x..y` = `::y ~ ::x`, plus `|` union,
`&` intersection, `~` difference. String patterns inside functions default to
glob; `exact:`, `substring:`, `regex:` (append `-i` for case-insensitive) also
work. See `references/revsets.md` for the full function list.

Useful user config (`~/.config/jj/config.toml`) if absent:
```toml
[revsets]
log = "mine() | trunk() | present(@)"   # widen the default log view
[revset-aliases]
'trunk()' = 'main@origin'              # pin your trunk
```
Or just pass `-r 'all()'` explicitly when commits seem missing.

## Gotchas

- **`jj abandon` on `@`** silently starts a fresh empty working copy — fine, it's
  undoable.
- **Empty changes are normal** in jj (that's the "nothing staged" state). Clean
  them with `jj abandon`; don't worry about them otherwise.
- **`jj git push` with no bookmark** does nothing useful — you must create/move a
  bookmark or use `-c <change>`. This is intentional safety.
- **Colocated repos**: git's HEAD, index, and refs are managed by jj. Running raw
  git mutating commands desyncs them; if it happens, `jj git import` then `jj undo`
  the git damage from the op log perspective.
- **`jj file untrack`** requires the path to match an ignore pattern, else the
  file gets re-snapshotted.
- **Interdiff/review of a rebase**: `jj interdiff -r X` diffs your change against
  its pre-rewrite version — handy after rebasing onto new trunk.
- **Config lives in** `~/.config/jj/config.toml` (user) and `.jj/repo/config.toml`
  (repo). Check `jj config list` before assuming defaults.
