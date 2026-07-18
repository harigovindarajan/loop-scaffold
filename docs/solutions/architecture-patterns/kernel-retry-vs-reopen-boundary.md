---
title: "Retry vs reopen: a kernel boundary that moved when state became derived"
date: 2026-06-21
category: architecture-patterns
module: loop-protocol
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - "Deciding which failure-recovery behaviors belong in a protocol kernel vs a higher layer"
  - "Re-deriving a kernel-vs-canon boundary after a change to the state model"
  - "Shipping a spec meant to be run cold by an agent"
tags: [loop-protocol, kernel-design, failure-taxonomy, retry, reopen, derived-state]
---

# Retry vs reopen: a kernel boundary that moved when state became derived

## Context

An early recorded-state version of this loop kept a progress ledger the agent updated
by hand. A live validation run surfaced a boundary question the spec hadn't made
explicit: a `verify` stage caught a defect that was actually rooted in the earlier
stage that produced the file. The taxonomy said a verify failure is a
`retryable-defect`, and retry "stays on the same stage" — so what does retry *mean*
when the real fix lives in an earlier stage?

The answer at the time was to keep the kernel minimal: retry meant same-stage
re-attempt only, and "reopen item to stage X" was pushed out of the kernel entirely.
Under recorded state that was the right call — reopen needed routing vocabulary
(which stage to return to, what state to reset, how checkpoints interact), all
bookkeeping the one file an agent reads cold could not afford.

The v2 kernel reversed the placement — and the reversal is the learning.

## Guidance

**Price a kernel behavior by the bookkeeping it forces, not by the concept.** Reopen
was expensive under recorded state because every backward move had to be *written*:
statuses reset, attempts reconciled, checkpoints re-armed. Under derived state
([`LOOP.md` §2](../../../LOOP.md#2-position-is-computed-never-stored)) reopen stopped
being an operation at all: repair the earlier stage's artifact and its hash no longer
matches the pass-commit, every downstream gate derives as stale, and the item's
position falls back *by itself*. The only vocabulary the kernel needed was one field —
`onFail`, naming which stage's executor owns the fix
([`LOOP.md` §5](../../../LOOP.md#5-failure-taxonomy)).

Two rules of thumb fall out:

- **Kernel boundaries are artifacts of the state model.** When the state model
  changes, re-derive the boundaries rather than inheriting them. A behavior correctly
  excluded yesterday may be free today.
- **Run the spec cold to find the seams.** A paper review of the early kernel passed;
  a live seven-iteration run is what exposed the retry/reopen ambiguity. Running the
  spec is the test.

## When to Apply

- Drawing a kernel-vs-canon (core-vs-extension) line for any recovery or routing
  behavior.
- Revisiting an old "too expensive for the kernel" decision after an architectural
  shift — especially recorded→derived state.
- Shipping any spec intended to be executed cold by an agent — run it end to end
  before trusting the review.

## Examples

The same defect, resolved under each model:

```text
recorded state (early kernel):
  verify fails on item-002 → retryable-defect → re-attempt ON verify,
  fixing the earlier stage's output in place; no backward routing exists.

derived state (v2 kernel):
  review fails on tc-05 → onFail: draft says the draft executor owns the fix
  → docs/tc-05.md is repaired → its hash diverges from draft's pass-commit
  → downstream gates derive as stale → position falls back with no bookkeeping.
```

The v2 mechanics are narrated end to end in
[`WALKTHROUGH.md`](../../../WALKTHROUGH.md) ("Staleness routes the reopen").

## Related

- [`LOOP.md` §2](../../../LOOP.md#2-position-is-computed-never-stored) — position
  derivation and staleness, the machinery that made reopen free.
- [`LOOP.md` §5](../../../LOOP.md#5-failure-taxonomy) — `retryable-defect` and
  `onFail` re-attempt routing.
- [`cross-item-artifact-reuse.md`](cross-item-artifact-reuse.md) — sibling learning on
  keeping artifact-layer concerns out of the kernel; this doc is the counterweight:
  a concern belongs *in* the kernel once the state model makes it free.
