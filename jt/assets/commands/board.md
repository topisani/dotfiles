---
description: Show the task board and lane state
argument-hint: [optional filter, e.g. "P1" or "auth"]
allowed-tools: Bash(jt:*)
---

!`jt status`

## Your task

Read-only. The board above is computed, so don't recompute it: add judgment. In a few lines, filtered to `$ARGUMENTS` if given:

- Phrase each blocked task as the actual question waiting on me, not its title.
- Call out anything in Problems that needs action, and what you'd do.
- End with the one task you'd pick up next, and why.
