# Prompt: construct-loop

Run the interview and emit a runnable loop for the user's task. Follow the three
blocks below in order: gather the **Input**, obey the **Canonical rules**, produce the
**Output**. The rules are references — the loop formats live in
[`LOOP.md`](../LOOP.md); do not restate them here or in your output.

---

## Input structure

Run the interview in [`INTERVIEW.md`](../INTERVIEW.md) and collect the answers into
the **answer set** it defines (`work_type`, `unit_of_work`, `phases`,
`approval_points`, `verification`, `handoff`, `failure_intent`) —
see [`INTERVIEW.md` §1, "Answer set"](../INTERVIEW.md#answer-set). That structure is
the input to everything below.

If an answer is absent, use the `INTERVIEW.md` fallback (one `agent` phase, no
checkpoints, one terminal `verify`).

---

## Canonical rules to follow

Check each before emitting. These are pointers, not definitions:

- **Compose stages** per the recipe in [`INTERVIEW.md` §2](../INTERVIEW.md) — phases →
  `agent`, approval points → `checkpoint`, verification → terminal `verify`. Compose
  fresh; do not copy a `scaffolds/` file as a shortcut (cite them only as examples).
- **Stage contract & kinds** — every emitted stage must satisfy the stage contract and
  the closed set of kinds defined in [`LOOP.md` §2](../LOOP.md#2-scaffold-shape), with the
  terminal stage's `next` being `null`. Point at §2 for the field and kind definitions; do
  not re-enumerate them here.
- **Seed the ledger** — one row per unit of work, at the entry stage, per
  [`LOOP.md` §6, "Seed the work items"](../LOOP.md#6-operating-the-loop). The row shape
  is [`LOOP.md` §3](../LOOP.md#3-work-item-row-shape).
- **Loop-level settings in scaffold metadata** — record the run-time answers that shape
  behavior but no stage in the scaffold's optional top-level `metadata`
  ([`LOOP.md` §2](../LOOP.md#2-scaffold-shape)): `metadata.verification` (Q5, what "pass"
  means), `metadata.failureIntent` (Q7, retry-vs-block-vs-human) plus the concrete caps it
  implies — `metadata.maxAttempts` (same-stage retries) and `metadata.maxReopens`
  (checkpoint reopens), each defaulting to 3 when omitted — and `metadata.reopenTargets` if
  the user names explicit reopen targets. This is the durable home that carries them into
  fresh sessions.
- **Handoff in metadata** — record the Q6 answer in each row's free-form `metadata`
  (e.g. `metadata.handoff`). Never add a top-level row field; never reference
  `handoff-templates/` as existing.
- **Acceptance stamp in metadata** — stamp each seeded row's `metadata` with
  `metadata.acceptedAt` (ISO-8601 of when the user accepted the scaffold). This is the
  on-disk trace that the acceptance gate (output step 3) ran before seeding; it reuses the
  same `metadata` channel — no new field, no new file. Strict-mode linting checks for it
  ([`LINTER.md`](../LINTER.md)).
- **Per-stage runbook docs** — when the user names rule or runbook docs a stage depends on
  (what a `verify` checks against, a `checkpoint`'s review rules), emit them in that
  stage's optional `instructions` field (a path or array of paths). Optional; see
  [`LOOP.md` §2](../LOOP.md#2-scaffold-shape).
- **Conformant output** — the emitted `loop.json` and ledger must conform to
  [`LOOP.md`](../LOOP.md); [`LINTER.md`](../LINTER.md) describes the
  machine-checkable contract for that conformance.
- **Reference, don't restate** — per [`AUTHORING.md`](../AUTHORING.md), point at
  `LOOP.md` for any format detail; do not re-declare the row or stage shape.

---

## Output structure

Emit, in this order — **scaffold first, ledger only after the user approves the
scaffold**, so a late stage change cannot strand rows at the wrong entry stage:

1. **`loop.json`** — the composed scaffold (`LOOP.md` §2 shape), with any per-stage
   runbook docs in each stage's optional `instructions` field and the loop-level settings
   (verification note, failure intent + retry budget, reopen targets) in the scaffold's
   top-level `metadata`.
2. **A verification note** — what the terminal `verify` stage checks (the Q5 answer),
   emitted into `metadata.verification` on the scaffold above.
3. **Present the composed scaffold to the user for adjustment** — they may add, remove,
   or reorder stages or move checkpoints — **before** the ledger is seeded.
4. **`loop.state.jsonl`** — *after the user accepts the scaffold* — one seeded row per
   unit of work at the accepted entry stage (`LOOP.md` §3 shape, seeded per §6), with the
   durable handoff and the `metadata.acceptedAt` acceptance stamp in each row's `metadata`.

If stages or the unit-of-work decomposition change before the first iteration, discard the
draft ledger and reseed from the accepted scaffold. Once accepted, run it with
[`prompts/run-one-iteration.md`](run-one-iteration.md).
