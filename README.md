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

**Construction is gated:** execution may not begin until `loop.json` is drafted, edited
by the user, and **committed** — the plan's commit is the acceptance
([`LOOP.md` §8](LOOP.md#8-operating-the-loop)).

## Quickstart

```sh
git init                      # the kernel requires a git repo
# 1. draft loop.json with your stages (see LOOP.md §1 for the shape), edit, commit it
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
| [`LOOP.md`](LOOP.md) | **v2 kernel.** Read first; everything else references it. |
| [`reconciler/`](reconciler/) | **Optional** CLI: `status` / `next` / `gate` / `note` / `validate` / `run`. Mechanizes the kernel; adds no rules. |
| `docs/solutions/` | Compounding-knowledge store (learnings from real runs). |

## Migration status (v1 → v2)

v1 — the recorded-state kernel (`loop.state.jsonl` ledger, journal, interview prompts,
shard-based batch canon, separate linter/runner) — is frozen on the **`v1` branch**. The
remaining v1 docs still present here (`INTERVIEW.md`, `JOURNAL.md`, `BATCH-EXECUTION.md`,
`LINTER.md`, `WALKTHROUGH.md`, `AUTHORING.md`, `prompts/`, `scaffolds/`, `runner/`) are
**pending rewrite or deletion** against the v2 kernel and should not be followed for a
v2 loop; the redesign rationale and cut list live in
`docs/plans/2026-07-03-relay-v2-artifact-graph-redesign.md` (on disk, unversioned).
Next milestone: re-run the Selenium→Playwright benchmark on v2 before those docs move.
