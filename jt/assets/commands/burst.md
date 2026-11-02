---
description: Knock out a run of small ready tasks, unattended
argument-hint: [optional focus, e.g. "the UI bugs" or a change id]
allowed-tools: Bash(jt:*), Bash(jj:*)
---

## Batch

!`jt next -n 8 --explain "$ARGUMENTS"`

## Your task

Work the tasks above back to back without checking in. This is the unattended counterpart to `/jt:start`: don't ask me things, park them.

That list is the whole run. It's already filtered to ready tasks clear of in-flight scope and capped at 8. Don't re-query mid-run; anything newly ready is the next run's problem.

**Small tasks only.** Leave out anything needing real design or a wide diff: it wants `/jt:start`.

For each, in order:

1. `jt start <id>`, then `jt show <id>`. The list above is deliberately body-less. If the body reveals it's bigger than it looked: `jt set <id> body=-` with what you learned, then `jt set <id> status=todo`, and move on. A task left `doing` is invisible to the next run.
2. Do the work inline; don't delegate. `jj file track <path>` for new files where auto-track is off.
3. `jt finish <id> -m "<message>"`: the change and why, not a log of the work. It runs verify and keeps only the failure tail. If it reports no verify is configured, run the command from `CLAUDE.md` first and keep only pass/fail. Needs my eyes? Add `--testing "<what to look at>"`.

Along the way:

- **Design fork:** `jt block <id> "<question>" -o "<option>" -o "<option>" --recommend N`, then the next task. Never guess, never stall.
- **Something new:** `jt new "…"` and keep going.
- **Broken tree** comes first: fix it before starting anything else.

Don't use `jj describe` on a task. Don't squash, merge, or move bookmarks.

Report one line per task (change id + what you did), anything blocked or skipped, and the final tip (`jt tip`).
