# Portable Agent Loop

The loop protocol for coding agents — as **docs, not a runtime**. Open the repo, read one
file, and run a single-agent linear loop: advance one stage at a time, persist each
transition, stop and resume cleanly. Building a loop for a task — turning it into work
items — is a separate, gated step (below). No engine to install, no agent-specific
lock-in.

## Start here

Read **[`LOOP.md`](LOOP.md)**. It is the whole kernel — the single source of truth for the
scaffold shape, the work-item row, the one-transition-per-iteration invariant, and the
failure taxonomy. Reading it alone lets you **run an already-constructed loop**: with a
`loop.json` and a seeded ledger in hand, you can advance it correctly.

**Building a loop for a task comes first, and it is gated — do not seed a ledger straight
from a task.** Read [`INTERVIEW.md`](INTERVIEW.md) and run
[`prompts/construct-loop.md`](prompts/construct-loop.md): interview the user, compose
`loop.json`, present it for acceptance, and seed `loop.state.jsonl` **only after the user
accepts the scaffold**. Composing, seeding, and executing in a single step — skipping the
interview and the acceptance gate — is the most common way the loop is misused.

## What's in the repo

| File | Purpose |
| --- | --- |
| [`LOOP.md`](LOOP.md) | The normative kernel. Read first; everything else references it. |
| [`WALKTHROUGH.md`](WALKTHROUGH.md) | A narrated worked trace: how a row moves through every code and stage kind. |
| [`INTERVIEW.md`](INTERVIEW.md) | The interview an agent runs, and how answers compose into a loop. |
| [`AUTHORING.md`](AUTHORING.md) | The one authoring rule: reference the kernel, never restate it. |
| [`LINTER.md`](LINTER.md) | Ready-to-build contract for the reference linter. |
| [`BATCH-EXECUTION.md`](BATCH-EXECUTION.md) | Canon for safe multi-agent batch execution via independent loop shards. |
| [`scaffolds/`](scaffolds/) | Copy-pasteable starter pipelines and an example ledger. |
| [`prompts/`](prompts/) | Runnable prompts: construct a loop, run one iteration, reopen a checkpoint-rejected item, resume a parked item. |
| [`runner/`](runner/) | **Optional** reference driver: run a loop in fresh sessions, one per iteration. Not required — the protocol is docs. |

## Quickstart

**Build a loop for your task (recommended).** Have an agent follow
[`prompts/construct-loop.md`](prompts/construct-loop.md): it runs the
[`INTERVIEW.md`](INTERVIEW.md) interview, composes a `loop.json`, presents the scaffold
for your adjustment, and then seeds the ledger from the accepted scaffold. Then run it
one step at a time with
[`prompts/run-one-iteration.md`](prompts/run-one-iteration.md).

**Or start from a shipped starter:**

```sh
cp scaffolds/loop.minimal.json loop.json   # 1. pick a pipeline (or loop.checkpoint.json)
# 2. seed loop.state.jsonl from your task   → LOOP.md §6, "Seed the work items"
# 3. run one item, one stage, one transition → LOOP.md §6, "Operating the loop"
# 4. stop or resume anytime — the ledger is the whole state
```

See [`scaffolds/README.md`](scaffolds/README.md) for choosing a starter and seeding the
ledger.

## Status

v1 ships the kernel (`LOOP.md`), the authoring rule, the ready-to-build linter contract,
the safe batch-execution canon, the scaffolds, the worked trace, the interview +
construct/run/reopen/resume-parked prompts, and the optional fresh-session runner. The remaining expository canon docs, prompts
(checkpoint review, failure classification), durable-handoff templates, migrations, agent
adapters, and the actual linter binary are forthcoming — each will reference `LOOP.md`
rather than re-declare it.
