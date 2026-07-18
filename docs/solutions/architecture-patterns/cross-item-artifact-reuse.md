---
title: "A stage reuses durable cross-item artifacts instead of re-deriving them per item"
date: 2026-06-30
category: architecture-patterns
module: loop-protocol
problem_type: architecture_pattern
component: development_workflow
severity: medium
applies_when:
  - "Designing a stage whose output is a function of something shared across work items"
  - "A stage is the slow or flaky long-pole of an otherwise cheap loop"
  - "Planning parallelism over a loop and worrying about merge contention"
tags: [loop-protocol, stage-design, caching, reuse, parallelism, performance]
---

# A stage reuses durable cross-item artifacts instead of re-deriving them per item

## Context

The kernel ([`LOOP.md`](../../../LOOP.md)) is deliberately per-item: an item's position
is derived stage by stage for that item alone (§2). It says nothing about sharing work
*between* items — by design, the kernel treats every item independently.

A live migration loop exposed where that silence bites. In a Selenium→Playwright
migration (`contract → probe → write → review → verify`), the `probe` stage drives a
live browser to ground each locator against the DOM. It was run **per test case**, so
the Home page was probed independently for five separate items — even though the
grounded locators were already accumulating in the page objects the tests import.
`probe` became the slowest, flakiest stage in the loop, re-deriving on every item what
an existing durable artifact already held.

The tell: the thing the stage produces is a function not of the *work item* but of
something the items *share* — locators belong to **pages**, not tests.

## Guidance

When a stage's output is a function of a durable artifact shared across work items,
**reuse that artifact rather than re-deriving it per item.**

- **Identify the real key.** Ask what the stage's output actually depends on. If two
  different items would produce the same output, that output is keyed by the shared
  thing (a page, a schema, a fixture), not by the item.
- **Prefer the store that already exists.** If a durable artifact already holds the
  derived result (page objects already hold grounded locators), treat *it* as the cache
  before inventing a second store — a parallel store drifts from the one the work
  actually consumes.
- **Add a secondary cache only to fill the gap**, keyed by the shared dimensions, and
  let the expensive derivation run only on a miss in every tier — then write the result
  back so the next item reuses it.
- **Keep it out of the kernel.** This is an artifact-layer concern. The kernel stays
  per-item; the reuse is wired through the stage's `with` map and its runbook
  ([`LOOP.md` §1](../../../LOOP.md#1-the-plan)), referencing the kernel rather than
  re-declaring it ([`CONTRIBUTING.md`](../../../CONTRIBUTING.md)).

## Why This Matters

Re-derivation is wasted work, but the deeper reason is that **the redundant-derivation
surface and the future merge-contention surface are the same surface.** The pages that
get re-probed per test are exactly the page objects two parallel agents would both edit.
So centralizing the derivation (grounding once into a shared, keyed artifact)
simultaneously makes the serial loop faster *and* is the prerequisite for safe
parallelism later — you cannot cleanly shard work whose every item re-derives the same
contended artifact.

It also keeps the kernel honest. The fix is not "teach the kernel about sharing" — that
would pull caching, keys, and invalidation into the one file an agent reads cold. The
kernel stays minimal; the reuse is composed on top, in the artifact layer.

## When to Apply

- A stage is the long pole of an otherwise cheap loop, and you notice it recomputing
  similar results across items.
- You are about to add a cache: first check whether a durable artifact the work already
  consumes can *be* the cache.
- You are scoping parallelism over a loop and need to know which artifacts are the
  contention surface — they are usually the ones a stage re-derives per item.

## Examples

The probe's tiered resolution — reuse before driving, derive only on a full miss:

```text
locator needed
  → Tier 1: existing page object holds it?          reuse, no live drive
  → Tier 2: per-loop probe cache (page+state+auth)?  reuse, no live drive
  → miss in both: drive live once, write back to the cache
```

Self-healing keeps the cache honest without coupling it to the kernel: a `verify`
failure caused by a locator that no longer resolves invalidates that cache entry, so
the next probe re-grounds it. The cache is a path the executor *writes* — named in the
stage's `with` map and gitignored in the loop repo, outside the hashed input set
([`LOOP.md` §4](../../../LOOP.md#4-the-gate-commit-invariant)) — so invalidating an
entry never disturbs gates or staleness.

## Related

- [`LOOP.md` §1](../../../LOOP.md#1-the-plan) — the `with` map, where a stage's cache
  and reference inputs are declared; this learning is why that field exists.
- [`LOOP.md` §4, §8](../../../LOOP.md#4-the-gate-commit-invariant) — batching,
  parallelism, and the gitignored-scratch convention the cache rides on.
- [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) — reference the kernel, never restate
  it; reuse is artifact-layer, not kernel.
- The `README.md` worked example wires this pattern directly: the probe stage's
  `with: { "page-objects": …, "locator-cache": … }`.
