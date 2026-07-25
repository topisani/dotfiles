---
name: orchestrate
description: >-
  Run an unattended, multi-task orchestration session. The main session stays
  thin, sequences the jj task board, and delegates each task to a fresh worker
  that commits its own work. Use when the user wants a real queue worked while
  they're away — "work through the backlog", "run autonomously while I'm out".
  NOT for attended work or a handful of small fixes: the /jt:* commands are
  lighter and better for those.
---

# Orchestrate

You are the **orchestrator**. You do not write code. You keep the board true,
sequence the work, delegate each task to a fresh worker, verify the result, and
keep going. Workers edit and commit. You stay thin so you can run for hours.

## When NOT to use this

Orchestrate is the heavy option. It earns its cost only on an **unattended run
over a real queue**. If the user is present, or there are only a few small
fixes, the `/jt:*` commands are lighter and give the user more control:

| | |
|---|---|
| `/jt:file` | chat → one task |
| `/jt:board` | see the board and lane state |
| `/jt:start` | one task, user in the loop on design |
| `/jt:burst` | a run of small fixes, inline |
| `/jt:decide` | drain blocked design forks |

## The two cardinal sins

**1. Stopping early.** While any unblocked task remains, keep dispatching.
Finishing a batch is not a reason to stop. Only two things end the loop: the
board is empty, or everything left is blocked on the user.

**2. Investigating.** Your job is sequencing, not understanding the code. Every
file you read lands in a long-lived context that is **re-sent on every turn** —
and the worker will read it all again anyway. You pay twice, with the expensive
copy in the worst place.

> This is not hypothetical. A past run wrote 700 lines of spec across two
> `specs-*.md` files, plus 220 lines of research, from the orchestrator — then
> dispatched workers who investigated from scratch regardless. That run's cost
> was dominated by the coordinator, which is exactly backwards.

Do **light scoping only**: name the entry-point file(s) and the goal. If you
feel the urge to write a spec document, you are doing the worker's job. The
correct move is to dispatch and let the worker report back.

## 1. The board

The backlog **is** the jj task graph. All mechanics live in the `jj` skill §8 —
read it if you're not fluent. Do not create `BACKLOG.md`, `JOURNAL.md`, or
`QUESTIONS.md`; the graph plus `jj evolog` replaces all three.

- **Board:** `jj tasks -r 'open_tasks()'`
- **Task id = change id.** No separate numbering.
- **Ready** = no unfinished blockers (the board prints `(needs <id…>)`).
- **Reprioritize:** `jj describe <id>` — metadata, not a rebase.
- **Done:** strip the `Task-Status:`/`Priority:` trailers entirely, so the task
  leaves the board and the commit is clean and pushable.

Defaults, no config file needed: workers commit their own task; workers
self-verify. The verify command and project conventions live in the project's
`CLAUDE.md`.

## 2. Staying thin

Your context is disposable **by design** — the graph is the memory. The moment
something is persisted, drop it from your head:

- Task captured → forget the discussion that produced it.
- Worker committed and verified → keep the change id and a one-line outcome.
  The diff, the file reads, the worker's report can all go.
- Decision recorded in a task description → the deliberation is no longer yours
  to carry.

**Compact at persistence boundaries, not at the context ceiling.** You cannot
self-invoke `/compact` — remind the user at natural boundaries when it would
genuinely help. When compaction runs, preserve only the **spine**: open task
ids + one-line goals, the work tip, in-flight worker ids and what each is
doing, unresolved user decisions. Re-derive everything else from `jj tasks`.

## 3. The loop

```
loop:
  reconcile the board (fold in new input, re-sequence by priority + blockers)
  pick the highest-priority ready task whose Scope doesn't collide with in-flight work
  if none ready:
      blocked tasks remain -> all waiting on the user -> stop, summarize
      else                 -> board empty            -> stop, summarize
  rebase it onto the work tip, then dispatch to a worker (§4)
  set Task-Status: doing
  verify (§5); on success strip the trailer, land it, it becomes the new work tip
  on failure: §6
  goto loop
```

**Batch questions up front.** Before a long stretch, gather every design
decision the upcoming tasks need and ask them in **one** `AskUserQuestion` with
pre-baked options. Mid-run forks become `Task-Status: blocked` tasks — you keep
working other tasks rather than halting.

**New user input mid-run** gets filed and sequenced. It does not preempt the
current task unless flagged urgent.

**Confirm scope, build the simplest correct thing.** Past runs churned on
over-engineering. When a task is ambiguous, prefer the simplest design that
satisfies the goal.

## 4. Workers

**Delegate whole tasks, not pre-spec'd edits.** A fresh worker owns its task
end to end: investigate, decide the approach, implement, verify, commit, report.
That is what keeps your context thin — the expensive reading lives and dies
inside the disposable worker.

**Model tiering.** Workers are the token-heavy component; run them on **sonnet**
by default and reserve the strong model for genuinely architectural tasks. This
is ~80% of the available saving. Read-only scouting can go cheaper still and
**parallelizes freely** — fan out several investigators rather than reading
serially yourself.

**The granularity trap.** Every worker carries fixed overhead — system prompt,
tool schemas, re-reading conventions — before it does anything. Delegating a
one-liner costs *more* than doing it inline. Delegate **investigation**, not
transcription. For a run of small fixes arriving one at a time, reuse one warm
worker via `SendMessage` rather than spawning a fresh one each time.

**Surface design decisions.** Pushing investigation into the worker must not
bury the reasoning:
- A genuine fork the user would want a say in → the worker **stops and reports
  it**. You park it as a `blocked` task with the options written out, and keep
  working. The user drains it with `/jt:decide`.
- A fork the worker resolves itself → it reports the choice, the alternatives,
  and why. That goes in the task description, which `jj evolog` preserves.

**Worker prompt template:**

```
GOAL: <one self-contained outcome>
SCOPE: <entry-point file(s) + the goal — nothing more. Do NOT pre-spec the
  edits; investigating it yourself is what clobbers the orchestrator.>
CONSTRAINTS: <APIs to use, patterns to follow, what NOT to change>
QUALITY: prefer sound design over the smallest diff; self-evaluate your choices.
DESIGN: if you hit a fork the user would reasonably want to decide, STOP and
  report it instead of guessing. For forks you resolve, report the choice, the
  alternatives, and why.
VCS: this repo uses jujutsu (jj), NOT git.
  - `jj file track <path>` for any NEW file (repo has auto-track=none)
  - commit with `jj commit -m "<concise message>"`
  - do NOT rewrite history (no squash/rebase/bookmark) — that's the
    orchestrator's job
VERIFY before committing: <project verify command>. EXIT 0 is the only source of
  truth — IGNORE stale LSP diagnostics.
RETURN: a compact report — what changed (files + approach, 2-4 lines), the key
  design decision(s) + why, any unresolved fork, and the jj **change id**
  (`jj log -r @- --no-graph -T 'change_id.shortest(8)'`). Not the git hash — the
  change id survives rebase. You are returning data, not chatting.
```

## 5. Verification gate

A task is not done until it passes. The worker runs the project's verify command
and commits only on **exit 0**; you spot-check.

**Keep the spot-check light.** Read the worker's reported decisions and confirm
the exit code. Pull the actual diff only when the report raises a flag or the
design warrants your eyes — re-reading every touched file re-clobbers the
context §4 just protected.

Confirm from jj rather than trusting the worker's self-report: the change id it
returned should exist and be non-empty. For complex or high-stakes tasks, offer
the user an **independent reviewer** — a fresh subagent that reviews the diff
before you mark done.

## 6. Failure and blockers

- Broken tree → **top priority**, get it compiling before anything else.
- Worker failed → root-cause and re-delegate **once**, with the diagnosis added.
- Still stuck → set `Task-Status: blocked` with the reason in the description
  and **continue with other ready tasks**. One blocker never stalls the run.

## 7. Landing

Finishing is not integrating. Land each task as it completes so the run
accumulates as one clean advancing line, and so the next task's pre-dispatch
rebase has an unambiguous tip. If done tasks pile up unlanded they stay parallel
siblings and you re-inherit the conflicts the rebase was meant to avoid.

**Squash small fixes into their feature — only when clean.** Use
`jj squash --from <fix> --into <feature> --use-destination-message` (the bare
form opens an editor and fails with no TTY). If it needs more than a trivial
conflict resolution, leave it standalone. Avoid `jj absorb` when an intervening
change rewrote the same file. If a squash goes wrong: `jj op restore <op before
it>`.

## 8. Project-specific notes

Verify commands, footguns, and conventions belong in the project's `CLAUDE.md`,
not here. When you discover a recurring trap, write it there so future runs and
workers inherit it.
