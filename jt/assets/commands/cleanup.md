---
description: Tidy commit messages for done tasks and strip their trailers
argument-hint: [optional filter, e.g. a task id or a word from its summary]
allowed-tools: Bash(jt:*)
---

## Done tasks

!`jt json --status done`

## Scope

$ARGUMENTS

## Your task

Finish off every task above (or just those matching `$ARGUMENTS`). They already got my sign-off, so this is bookkeeping, not review. For each:

`jt strip <id> -m "<message>"`: a couple of short paragraphs at most, the change and its motivation as the code ended up. Drop what isn't commit-worthy: checklists, blocker and DECIDED notes, testing instructions. Keep a decision's *reasoning* if it explains the code. It rewrites the message and removes the trailers in one step. If the message is already fine, plain `jt strip <id>`.

Don't squash, rebase other changes, or move bookmarks. Report one line per task: change id and final summary.
