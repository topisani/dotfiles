---
description: File a feature request or bug report as a jj task
argument-hint: [what's broken / what you want]
allowed-tools: Bash(jt:*), AskUserQuestion
---

## Open board

!`jt list`

## Request

$ARGUMENTS

## Your task

File the request as **one** task. No code, no starting it, no investigation beyond a quick look to scope it.

1. **Dedupe.** Already on the board: say which and stop. Refines an existing task: update that one (`jt show <id>`, then `jt set <id> body=-` with the merged detail on stdin).
2. **Create it:** `jt new "<summary, 80 characters at most>" -p P2 -s "path/a, path/b" --body "<detail>"`, adding `-b <id>` for each task it really depends on.
   - `-p` P0..P3, calibrated against the board.
   - `-s` the files you'd expect to touch. This is what collision detection runs on. Approximate is fine.
   - `--body` for a bug: reproduction, observed vs expected. For a feature: what and why, not how.
3. **At most one question**, via `AskUserQuestion`, only if you can't assign priority or scope without it. A vague task filed now beats an interrogation.

Report the change id and summary. Nothing else.
