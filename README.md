# Portable Agent Loop

The loop protocol for coding agents — as **docs, not a runtime**. Version 2, the
**artifact-graph kernel**: the plan declares, per stage, the artifact it produces, the
gate that proves it, and the executor that does it. An item's position is *derived* —
the first stage whose gate doesn't pass — never written; every gate-pass is a git
commit, so the run history is the git log. There is no state ledger to keep in sync,
nothing to drift, nothing to fake.

## Start here

Read **[`LOOP.md`](LOOP.md)** — the whole kernel, and the single source of truth for
the plan shape, the position function, the gate–commit invariant, and the failure
taxonomy. Reading it plus an accepted `loop.json` is everything an agent needs.

**Building the plan comes first, and it is gated.** Follow
[`CONSTRUCT.md`](CONSTRUCT.md): elicit (checklist, in the user's vocabulary), compose
`loop.json`, let the user edit the file itself, and **execute nothing until the plan is
committed** — the commit is the acceptance.

## Quickstart

```sh
git init                      # the kernel requires a git repo
# 1. build loop.json via CONSTRUCT.md (examples/ shows the shape), edit, commit it
# 2. derive positions, pick, execute, gate, commit — LOOP.md §8
#    …or let the reconciler mechanize it:
reconciler/loop status        # where is every item? (also validates the plan)
reconciler/loop next          # what to do now
reconciler/loop gate tc-01 probe    # run the gate; commit the proof on pass
reconciler/loop run           # fresh agent session per pick, unattended
```

## What's in the repo

| Path | Purpose |
| --- | --- |
| [`LOOP.md`](LOOP.md) | **The v2 kernel.** Read first; everything else references it. |
| [`CONSTRUCT.md`](CONSTRUCT.md) | Task → accepted plan: elicitation checklist, vocabulary map, compose, commit-as-acceptance. |
| [`WALKTHROUGH.md`](WALKTHROUGH.md) | Narrated trace: gates, staleness reopen, approval graduation, parking, resume. |
| [`examples/`](examples/) | Starter plans — example outputs of the construction flow. |
| [`prompts/run-one-pick.md`](prompts/run-one-pick.md) | The one runnable prompt: advance the loop by a single pick. |
| [`reconciler/`](reconciler/) | **Optional** CLI: `status` / `next` / `gate` / `note` / `validate` / `run`. Mechanizes the kernel; adds no rules. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The one authoring rule: reference the kernel, never restate it. |
| [`STRATEGY.md`](STRATEGY.md) | Product strategy, metrics (read from git log + notes), track status. |
| `docs/solutions/` | Compounding-knowledge store (learnings from real runs). |

## Status

v2 (this branch) ships the artifact-graph kernel, the construction canon, the worked
trace, the starter plans, and the reconciler CLI — replacing v1's recorded-state ledger,
journal, interview prompts, shard-based batch canon, and separate linter/runner
contracts. v1 is frozen on the **`v1` branch**; the redesign rationale and evidence live
in `docs/plans/2026-07-03-relay-v2-artifact-graph-redesign.md` (on disk, unversioned).
Merging v2 to `main` is gated on re-running the Selenium→Playwright benchmark against
this kernel.
