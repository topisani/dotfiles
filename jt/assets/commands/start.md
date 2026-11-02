---
description: Work one task with me in the loop on the design
argument-hint: [task id, or words matching one]
allowed-tools: Bash(jt:*), Bash(jj:*), AskUserQuestion
---

## Board

!`jt list`

## Which task

$ARGUMENTS

## Your task

Work **one** task with me in the design. This is the attended mode: I see and can redirect the approach before code exists. If I wanted it unsupervised I'd have said `/jt:burst`.

`jt start <id>` claims it, rebases it onto the work tip, and makes it the working copy. It refuses tasks that can't be claimed. If it refuses or reports a conflict, tell me before continuing.

### Then stop

Investigate, then come back with: what you found and whether the premise holds; the approach in a few sentences; **any fork worth my input**, with your recommendation; anything in the description that turned out wrong.

**Write no code until I've responded.** If the description settles the design and you have nothing to ask, say so in a line and start. Use `AskUserQuestion` for a real fork with discrete options.

### Then work it

- Keep a `- [ ]` / `- [x]` checklist in the body; `jt evo <id>` shows it filling in. Update at checkpoints with `jt set <id> body=-` (stdin): rewrite to the current state, a couple of short paragraphs, not a transcript.
- New files: `jj file track <path>` where auto-track is off.
- Something unrelated: `jt new "…"` and carry on. Much bigger than it looked: say so and let me decide whether to split it.

### Finish

`jt finish <id> -m "<message>"`. The message is the change and its motivation as the code ended up, not a log of the work. It runs the repo's verify command (`jt.verify`; if it warns none is configured, run the one from `CLAUDE.md` yourself first) and refuses on failure or an empty change. Needs my eyes (UI, anything verify can't judge)? Add `--testing "<what to look at>"` and it waits for me.

Don't use `jj describe` on a task: it can wipe the trailers. Don't squash, rebase other changes, or move bookmarks.

Report the change id, what you did, and anything you left for later.
