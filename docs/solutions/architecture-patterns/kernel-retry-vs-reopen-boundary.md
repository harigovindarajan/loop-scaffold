---
title: "Keep retry in the kernel, push reopen to canon"
date: 2026-06-21
category: architecture-patterns
module: loop-protocol
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - "Designing a minimal protocol kernel with a stage/iteration model"
  - "Deciding which failure-recovery behaviors belong in the core vs a higher layer"
  - "Writing a spec meant to be run cold by an agent"
tags: [loop-protocol, kernel-design, failure-taxonomy, retry, reopen, minimal-subset]
---

# Keep retry in the kernel, push reopen to canon

## Context

`LOOP.md` is the minimal normative kernel of the portable agent loop: a work item
advances one stage per iteration through a linear pipeline (`implement → review →
verify`), and each stage attempt resolves to one failure-taxonomy code (`pass`,
`retryable-defect`, `blocked-environment`, `human-exception`). The kernel deliberately
excludes richer topologies — those live in the referencing canon docs.

A live validation run surfaced a boundary question the spec hadn't made explicit. A
`verify` stage caught a defect (`wordcount.txt` held the wrong value), but the defect
was actually rooted in the earlier `agent` stage that produced the file. The taxonomy
says a `verify` failure is a `retryable-defect`, and `retryable-defect` "stays on the
same stage." So what does retry *mean* when the real fix lives in an earlier stage?

## Guidance

In a linear loop kernel, define **retry as same-stage re-attempt only**, and treat
**reopening to a specific earlier stage as a separate, richer behavior that belongs in
the canon layer, not the kernel.**

- `retryable-defect` → stay on the current stage, increment `attempts`, fix in place,
  re-attempt. The kernel never routes an item backward to a named earlier stage.
- When a defect surfaced at stage N is rooted in stage N−k, the same-stage re-attempt
  fixes it in place. That is sufficient for the kernel's single-agent linear case.
- "Reopen item to stage X" is a routing decision with its own targets and rules. It is
  additive complexity (which stage to return to, what to reset, how checkpoints
  interact). Keep it out of the minimal subset; let canon docs that reference the
  kernel define it.

The general principle: when carving a minimal kernel out of a richer model, keep the
**in-place** recovery primitive (retry) in the kernel and push the **routing** primitive
(reopen/branch to a different stage) to a higher layer. In-place recovery needs no extra
vocabulary; routing does.

## Why This Matters

Pulling reopen into the kernel would have forced reopen-target vocabulary, reset rules,
and checkpoint-interaction semantics into the one file an agent must read cold — directly
against the kernel's reason for existing (a minimal runnable subset). Leaving the boundary
*implicit*, though, is its own failure: an implementer could reasonably assume a
`verify` failure routes back to `implement` and build the kernel wrong. Naming the
boundary in one sentence costs nothing and prevents that misread.

This also demonstrated that **a cold-readable spec should be validated by actually
running it, not just reviewed.** A paper review of `LOOP.md` passed; a live 7-iteration
run is what exposed the retry/reopen seam (and, separately, a missing row-seeding step
and a `pending → in-progress` flip). Running the spec is the test.

## When to Apply

- Defining or reviewing the failure/recovery model of a loop or pipeline kernel.
- Drawing a kernel-vs-canon (or core-vs-extension) line and deciding where a recovery
  behavior sits.
- Shipping any spec intended to be executed cold by an agent — run it end to end before
  trusting the review.

## Examples

Boundary made explicit in the kernel (`LOOP.md` §4), one sentence rather than a new
mechanism:

> `retryable-defect` always re-attempts the **same** stage — the kernel never reopens an
> item to an earlier stage. When a defect surfaced at one stage is rooted in an earlier
> one (e.g. a `verify` failure caused by bad `agent` output), the re-attempt fixes it in
> place. Reopening to a specific earlier stage is a richer behavior that lives in the
> canon, not this kernel.

Live run that exposed it (`implement → review → verify`, two work items):

```text
iter 6: item-002 verify — actual wc=2 vs file=3 → retryable-defect
        (stay stage=verify, attempts=1, lastError set)
iter 7: item-002 verify re-attempt — agent corrects the artifact in place → pass → done
```

The re-attempt happened *on `verify`*, not by routing back to `implement` — which is
exactly the kernel's intended (now documented) behavior.

## Related

- `LOOP.md` §4 (failure taxonomy) and §6 (operating the loop) — the kernel this learning
  refined.
- [`prompts/reopen-item.md`](../../../prompts/reopen-item.md) — the canon home for the
  reopen-to-earlier-stage behavior deferred out of the kernel (used for checkpoint
  rejections).
