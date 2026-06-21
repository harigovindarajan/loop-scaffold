# INTERVIEW.md

How a coding agent turns a user's task into a runnable loop. You ask a short
interview, map the answers to a pipeline with the recipe below, and emit the loop
per the output contract. This doc defines **what to ask** and **how answers become a
loop**; it does not re-declare the loop formats — those live in
[`LOOP.md`](LOOP.md), and you reference them.

Voice is agent-first. The interview is for a human user (A2); you (A1) run it. Keep
it agent-agnostic — nothing here assumes a specific agent or tool.

---

## 1. The interview

Ask these six questions, in order. Each answer feeds the composition recipe (§2) or
the run-time behavior noted. Ask one at a time; keep them short.

1. **What kind of work is this?** — framing only (e.g. a migration, a feature, a
   refactor). Orients the rest of the interview; does not by itself create stages.
   → `work_type`
2. **What is one unit of work?** — the smallest thing that makes sense to carry
   through the pipeline independently. Becomes one work-item row per unit when you
   seed (`LOOP.md` §6). → `unit_of_work`
3. **What are the execution phases of one unit?** — the ordered steps each unit goes
   through (e.g. *implement*, then *migrate data*). Becomes the `agent` stages (§2).
   → `phases`
4. **Where are the approval or uncertainty points?** — places where a named artifact
   should be reviewed before moving on, and at which phase. Becomes `checkpoint`
   stages inserted at those positions (§2). → `approval_points` (may be empty)
5. **What counts as verification?** — the check that decides the unit is done (e.g. a
   test suite, a schema diff). Becomes the terminal `verify` stage (§2).
   → `verification`
6. **What is the durable handoff between phases?** — the artifact a later phase
   consumes from an earlier one (e.g. *review notes*, *a migration report*). Captured
   as guidance, not a stage (§2, handoff row). → `handoff`
7. *(Run-time, not a stage.)* **What should cause retry vs block vs human
   escalation?** — record the user's intent so that at run time you classify outcomes
   per the failure taxonomy in [`LOOP.md` §4](LOOP.md#4-failure-taxonomy). This shapes
   no stage; it guides classification later. → `failure_intent`

If an answer is missing, fall back to the leanest sensible default: one `agent`
phase, no checkpoints, a single `verify` at the end.

### Answer set

Capture the answers into this structure — it is the interview's output and the input
the construct prompt consumes:

```text
work_type:        <framing, e.g. "data migration">
unit_of_work:     <the smallest independently-runnable unit>
phases:           [<ordered execution phase>, ...]                               # Q3
approval_points:  [{ after_phase: <phase>, artifact: <what is reviewed> }, ...]  # Q4, may be empty
verification:     <what decides a unit is done>                                  # Q5
handoff:          <the durable artifact a later phase consumes>                  # Q6
failure_intent:   <user's retry vs block vs human guidance>                      # Q7, run-time only
```

---

## 2. The composition recipe

Map the answers to a pipeline. Compose the loop **fresh** from this recipe every
time — the shipped `scaffolds/` files are example outputs of it, not shortcuts.

| Interview answer | Composed into |
| --- | --- |
| Each ordered execution phase (Q3) | One `agent` stage, chained to the next by `next` |
| An approval / uncertainty point at a phase (Q4) | A `checkpoint` stage inserted at that position |
| What counts as verification (Q5) | The terminal `verify` stage, with `next: null` |
| The durable handoff (Q6) | Recorded in each work item's `metadata`, **not** a stage |
| One unit of work (Q2) | One seeded work-item row |
| Retry vs block vs human (Q7) | No stage — classified at run time via `LOOP.md` §4 |

The stage contract (`name`, `kind`, `next`) and the closed set of kinds
(`agent`, `checkpoint`, `verify`) are defined in
[`LOOP.md` §2](LOOP.md#2-scaffold-shape). Compose only valid stages; the first stage
is the entry stage for every unit.

**Worked example.** Answers — phases: *implement*; approval before merge: yes;
verification: a test suite — compose:

```text
implement (agent) → review (checkpoint) → verify (verify, next: null)
```

Phases-only answers with no approval point compose a checkpoint-free pipeline ending
in `verify` (the shape of `scaffolds/loop.minimal.json`).

---

## 3. Output contract

When the interview is done, produce:

- **A scaffold** — a `loop.json` whose `stages` are the composed pipeline, in the
  shape of [`LOOP.md` §2](LOOP.md#2-scaffold-shape). It must be well-formed by the
  [`LINTER.md`](LINTER.md) checks.
- **A seeded ledger** — one `loop.state.jsonl` row per unit of work, seeded per
  [`LOOP.md` §6, "Seed the work items"](LOOP.md#6-operating-the-loop). The row shape
  is defined in [`LOOP.md` §3](LOOP.md#3-work-item-row-shape) — do not re-declare it.
- **Captured handoff guidance** — the Q6 answer recorded in each row's free-form
  `metadata` (e.g. `metadata.handoff`). This slice ships no handoff template files;
  do not reference a `handoff-templates/` directory as if it exists.
- **A verification plan** — what the terminal `verify` stage checks (the Q5 answer),
  noted so the run knows what "pass" means.

Present the composed loop to the user and let them adjust it — add, remove, or
reorder stages, move checkpoints — **before** the first iteration. The composed loop
is a sensible starting point, not a lock.

To run it, follow [`prompts/run-one-iteration.md`](prompts/run-one-iteration.md).
