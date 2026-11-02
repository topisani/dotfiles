---
description: Drain blocked tasks — answer the design forks waiting on me
argument-hint: [optional task id to decide just one]
allowed-tools: Bash(jt:*), AskUserQuestion
---

## Open forks

!`jt decide --list`

## Scope

$ARGUMENTS

## Your task

These are design forks workers parked rather than guessing at. Walk me through them and record what I decide. **That is the only thing you're doing**: no code, no starting tasks. (`jt decide` in a terminal does this without you; your value is explaining the trade-offs and spotting when one answer settles several.)

For each (or just the one in `$ARGUMENTS`):

1. **Ask with `AskUserQuestion`.** Use the task's `options`, the `recommended` one first and marked `(Recommended)`. Make the trade-offs concrete: I should be able to decide from the question alone. If the fork is vague, say so and ask the real question.
2. **Record it**, which also clears the question and unblocks the task:
   - `jt decide <id> --option <key> ["why"]` or `jt decide <id> "<what was decided and why>"`.
   - Answer makes the task moot: add `--moot`.
   - I'd rather not decide now: `jt defer <id> "<why>"`. It isn't raised again until I revive it.
3. **Cascade.** If the decision settles another open fork, resolve that too and tell me. Don't ask me twice.

Batch forks into one `AskUserQuestion` where they're genuinely one decision. If nothing is open, say so in one line and stop.
