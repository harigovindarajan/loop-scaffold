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
- **Stage contract & kinds** — every stage has `name`, `kind`, `next`; `kind` is one
  of `agent | checkpoint | verify`; the terminal stage has `next: null`. See
  [`LOOP.md` §2](../LOOP.md#2-scaffold-shape).
- **Seed the ledger** — one row per unit of work, at the entry stage, per
  [`LOOP.md` §6, "Seed the work items"](../LOOP.md#6-operating-the-loop). The row shape
  is [`LOOP.md` §3](../LOOP.md#3-work-item-row-shape).
- **Handoff in metadata** — record the Q6 answer in each row's free-form `metadata`
  (e.g. `metadata.handoff`). Never add a top-level row field; never reference
  `handoff-templates/` as existing.
- **Well-formed output** — the emitted `loop.json` and ledger must pass the
  [`LINTER.md`](../LINTER.md) checks.
- **Reference, don't restate** — per [`AUTHORING.md`](../AUTHORING.md), point at
  `LOOP.md` for any format detail; do not re-declare the row or stage shape.

---

## Output structure

Emit, in this order:

1. **`loop.json`** — the composed scaffold (`LOOP.md` §2 shape).
2. **`loop.state.jsonl`** — one seeded row per unit of work (`LOOP.md` §3 shape, seeded
   per §6), with the durable handoff in each row's `metadata`.
3. **A verification note** — what the terminal `verify` stage checks (the Q5 answer).

Then **present the composed loop to the user for adjustment** — they may add, remove,
or reorder stages or move checkpoints — **before** the first iteration. Once they
accept it, run it with [`prompts/run-one-iteration.md`](run-one-iteration.md).
