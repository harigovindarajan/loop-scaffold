# Portable Agent Loop

The loop protocol for coding agents — as **docs, not a runtime**. Open the repo, read one
file, and run a single-agent linear loop over your task: establish work items, advance one
stage at a time, persist each transition, stop and resume cleanly. No engine to install, no
agent-specific lock-in.

## Start here

Read **[`LOOP.md`](LOOP.md)**. It is the whole kernel — the single source of truth for the
scaffold shape, the work-item row, the one-transition-per-iteration invariant, and the
failure taxonomy. With `LOOP.md` and a task, you can run a correct loop. If you only read
one file, read that one.

To build a loop **for a specific task**, read [`INTERVIEW.md`](INTERVIEW.md): it tells an
agent what to ask the user and how to turn the answers into a pipeline.

## What's in the repo

| File | Purpose |
| --- | --- |
| [`LOOP.md`](LOOP.md) | The normative kernel. Read first; everything else references it. |
| [`INTERVIEW.md`](INTERVIEW.md) | The interview an agent runs, and how answers compose into a loop. |
| [`AUTHORING.md`](AUTHORING.md) | The one authoring rule: reference the kernel, never restate it. |
| [`LINTER.md`](LINTER.md) | Contract for the deferred reference linter (built in v1.1). |
| [`scaffolds/`](scaffolds/) | Copy-pasteable starter pipelines and an example ledger. |
| [`prompts/`](prompts/) | Runnable prompts: construct a loop, run one iteration, reopen a checkpoint-rejected item, resume a parked item. |

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

v1 ships the kernel (`LOOP.md`), the authoring rule, the linter contract, the scaffolds,
and the interview + construct/run/reopen/resume-parked prompts. The expository canon docs,
the remaining prompts (checkpoint review, failure classification), durable-handoff
templates, worked examples, and agent adapters are forthcoming — each will reference
`LOOP.md` rather than re-declare it.
