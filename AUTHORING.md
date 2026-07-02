# AUTHORING.md

How to write canon docs for this repo. One rule governs everything below.

## The rule: reference the kernel, never restate it

`LOOP.md` is the **single source of truth** for the normative kernel — the work-item
row shape, the stage contract, the one-transition-per-iteration invariant, and the
failure taxonomy. Every other doc in this repo references `LOOP.md` for those things and
adds only its own expository or non-linear material on top.

No canon doc may normatively re-declare the row shape, the stage contract, the failure
taxonomy, or the invariant. If a doc needs them, it **links** to the relevant `LOOP.md`
section.

### The review test

> If a reviewer finds the row shape (or stage contract, or failure taxonomy, or
> invariant) normatively defined in two places, this rule has failed.

The kernel must appear in exactly one place. A second normative declaration anywhere in
the repo is a defect, even if the two copies currently agree — because they will drift.

## Preferred form vs. anti-pattern

**Do** — reference the kernel and add only what is new:

> Each work item moves through the stages defined in this pipeline. For the row shape and
> the meaning of `status`, `stage`, and `attempts`, see [`LOOP.md` §3](LOOP.md#3-work-item-row-shape).
> This doc adds the *review* stage's rejection-and-reopen behavior:

**Don't** — re-declare the kernel:

> A work item has `id`, `status`, `stage`, `attempts`, `lastError`, `needsHuman`,
> `artifacts`, `updatedAt`, and `metadata`, where `status` is one of pending,
> in-progress, blocked, needs-human, or done...

The second form is the drift this repo exists to avoid. Delete it and link instead.

## What belongs where

- **Kernel (`LOOP.md`)** — the minimal runnable subset: row shape, stage contract,
  invariant, failure taxonomy, operating rules, adapter stub.
- **Canon docs** — everything expository and non-linear that references the kernel:
  pipeline shapes, checkpoint behavior, durable handoffs, worked examples, migrations,
  multi-agent loops.
- **Adapters** — thin, agent-specific invocation details layered on the kernel's
  operating steps; no duplicated protocol logic.

When you are unsure whether something is kernel or canon: if an agent needs it to run a
single-agent linear loop cold, it is kernel and already lives in `LOOP.md`; otherwise it
is canon and references the kernel.
