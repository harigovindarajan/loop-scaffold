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

## What's in the repo

| File | Purpose |
| --- | --- |
| [`LOOP.md`](LOOP.md) | The normative kernel. Read first; everything else references it. |
| [`AUTHORING.md`](AUTHORING.md) | The one authoring rule: reference the kernel, never restate it. |
| [`LINTER.md`](LINTER.md) | Contract for the deferred reference linter (built in v1.1). |
| [`scaffolds/`](scaffolds/) | Copy-pasteable starter pipelines and an example ledger. |

## Quickstart

```sh
cp scaffolds/loop.minimal.json loop.json   # 1. pick a pipeline (or loop.checkpoint.json)
# 2. seed loop.state.jsonl from your task   → LOOP.md §6, "Seed the work items"
# 3. run one item, one stage, one transition → LOOP.md §6, "Operating the loop"
# 4. stop or resume anytime — the ledger is the whole state
```

See [`scaffolds/README.md`](scaffolds/README.md) for choosing a starter and seeding the
ledger.

## Status

v1 ships the kernel (`LOOP.md`), the authoring rule, the linter contract, and the
scaffolds. The expository canon docs, prompt pack, worked examples, and agent adapters are
forthcoming — each will reference `LOOP.md` rather than re-declare it.
