# Revset language reference

Condensed from https://www.jj-vcs.dev/latest/revsets/. A revset is a functional
expression selecting a set of revisions. Most `jj` commands accept one; commands
like `jj edit` require it to resolve to exactly one commit.

## Symbols

- `@` — working-copy commit; `<workspace>@` for another workspace
- `<name>@<remote>` — remote-tracking bookmark/tag (e.g. `main@origin`)
- Commit ID / change ID (full or unique prefix)
- `<change-id>/<offset>` — to address divergent or hidden commits
- Quote to disable parsing: `'"x-"'` is the symbol `x-`, not parents
- Resolution priority: tag → bookmark → commit/change ID. Override with
  `commit_id(abc)` / `bookmark(abc)` in scripts.

## Operators (strongest → weakest binding)

| Operator | Meaning |
|---|---|
| `f(x)` | function call |
| `x-` / `x+` | parents / children |
| `p:x` | string/date pattern alias |
| `x::` | descendants of x (incl. x) |
| `x..` | not ancestors of x |
| `::x` | ancestors of x (incl. x, incl. root) |
| `..x` | ancestors of x, excl. root |
| `x::y` | descendants of x that are ancestors of y (= `git log --ancestry-path x..y`) |
| `x..y` | ancestors of y not ancestors of x (= `::y ~ ::x`, same as git) |
| `::` / `..` | all visible commits / all except root |
| `~x` | complement |
| `x & y` / `x ~ y` | intersection / difference |
| `x \| y` | union |

Note: `(A | B)..` = `A.. & B..` (does not distribute over `|`).

## Functions

Structure/graph:
- `parents(x[,depth])`, `children(x[,depth])`, `ancestors(x[,depth])`, `descendants(x[,depth])`
- `first_parent(x)`, `first_ancestors(x)` — merge commits: follow 1st parent only
- `reachable(srcs, domain)` — e.g. `reachable(@, mutable())` = your current stack
- `connected(x)` = `x::x`
- `heads(x)` / `roots(x)` — members not ancestors/descendants of other members
- `latest(x[,count])` by committer timestamp
- `fork_point(x)`, `merge_point(x)`, `bisect(x)`
- `exactly(x, count)` — assert size (useful with 1 in scripts)
- `merges()`, `forks()`, `empty()` (no file changes)
- `all()`, `none()`, `visible_heads()`, `root()`

Identity/metadata:
- `change_id(prefix)`, `commit_id(prefix)`
- `description(pattern)`, `subject(pattern)` (first line)
- `author(pattern)`, `author_name`, `author_email`, `author_date(pattern)`
- `committer(...)`, `committer_date(pattern)`, `mine()`
- `signed()`

Refs:
- `bookmarks([pattern])` — local bookmark targets
- `remote_bookmarks([name_pat], [remote_pat])` — includes untracked; excludes
  git-tracking bookmarks by default (`remote="*"` to include)
- `tracked_remote_bookmarks(...)`, `untracked_remote_bookmarks(...)`
- `tags([pattern])`, `remote_tags(...)`, `working_copies()`

Content:
- `files(fileset)` — commits touching paths (relative to cwd; `files(src/)` = dir)
- `diff_lines(text[,files])` — pickaxe; also `diff_lines_added`, `diff_lines_removed`
- `conflicts()` — commits with conflicted files
- `divergent()` — divergent changes

Existence:
- `present(x)` — `none()` instead of error if x missing
- `coalesce(rs1, rs2, ...)` — first non-empty
- `at_operation(op, x)` — evaluate x at an old operation (time travel)

## String patterns

Default is glob. Kinds: `exact:`, `glob:`, `substring:`, `regex:`; append `-i`
for case-insensitive (`glob-i:"fix*jpeg*"`). Combinable: `~`, `&`, `~`, `|`,
e.g. `bookmarks(~glob:"ci/*")`.

## Date patterns

`after:"2024-02-01"`, `before:"yesterday 5pm"`, `"2 days ago"`,
`"2024-02-01T12:00:00-08:00"` etc.

## Built-in aliases (overridable in `[revset-aliases]`)

- `trunk()` — default-branch head of upstream/origin; override:
  `'trunk()' = 'main@origin'` (must resolve to exactly one commit)
- `immutable_heads()` — `trunk() | tags() | untracked_remote_bookmarks() | untracked_remote_tags()`
- `immutable()` = `::(immutable_heads() | root())`; `mutable()` = `~immutable()`
- Default `jj log` revset is `present(@) | ancestors(immutable_heads().., 2) | trunk()`

## Handy examples

```
jj log -r @-                          # parent of working copy
jj log -r '::@'                       # ancestors of @ (like git log)
jj log -r 'remote_bookmarks()..'      # local-only commits
jj log -r 'remote_bookmarks(remote=origin)..'
jj log -r '(remote_bookmarks()..@)::' # my stack + descendants
jj log -r 'mine() & description(*fix*)'
jj log -r 'files(src/auth/) & mine()'
jj log -r 'diff_lines("*TODO*", "src")'
jj log -r 'conflicts()'               # everything still conflicted
jj log -r 'divergent()'               # resolve these
jj log -r 'heads(mutable())'          # my loose ends
jj log -r 'reachable(@, mutable())'   # my current stack
jj log -r 'tags() | bookmarks()'      # decorated highlights
jj log -r 'at_operation(@-, visible_heads())'  # heads before last op
```
