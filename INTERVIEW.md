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

Ask the questions below, in order — Q1–Q6 shape the loop; Q7 is run-time only. Each
answer feeds the composition recipe (§2) or the run-time behavior noted. Ask one at a
time; keep them short.

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

If the user names rule or runbook docs a stage depends on — what a `verify` checks
against, or the rules a `checkpoint` review enforces — record them in that stage's
optional `instructions` field (`LOOP.md` §2). It is optional; omit it for stages with no
dedicated docs.

**Worked example.** Answers — phases: *implement*; approval before merge: yes;
verification: a test suite — compose:

```text
implement (agent) → review (checkpoint) → verify (verify, next: null)
```

Phases-only answers with no approval point compose a checkpoint-free pipeline ending
in `verify` (the shape of `scaffolds/loop.minimal.json`).

---

## 3. Output contract

When the interview is done, produce these in order — **scaffold first, ledger only after
the user approves the scaffold**, so a late stage change cannot strand rows at the wrong
entry stage:

1. **A scaffold** — a `loop.json` whose `stages` are the composed pipeline, in the
   shape of [`LOOP.md` §2](LOOP.md#2-scaffold-shape). It must conform to
   [`LOOP.md`](LOOP.md); [`LINTER.md`](LINTER.md) describes the machine-checkable
   contract for that conformance. Where a stage has dedicated rule or runbook docs (e.g.
   the rules a `verify` checks against, or a `checkpoint`'s review rules), record them in
   that stage's optional `instructions` field (`LOOP.md` §2) — a path or array of paths.
   Record the loop-level answers that shape *run-time behavior* — not stages — in the
   scaffold's optional top-level `metadata` (`LOOP.md` §2): the verification note
   (`metadata.verification`, Q5), the failure-intent guidance (`metadata.failureIntent`, Q7)
   and its concrete retry caps (`metadata.maxAttempts` / `metadata.maxReopens`, each
   defaulting to 3), and any reopen targets (`metadata.reopenTargets`). This is what carries
   them into fresh sessions, which hold nothing but the files on disk.
2. **A verification plan** — what the terminal `verify` stage checks (the Q5 answer),
   recorded in the scaffold's `metadata.verification` so the run knows what "pass" means.
3. **Present the scaffold for adjustment.** Show the composed loop and let the user add,
   remove, or reorder stages and move checkpoints. The composed loop is a sensible
   starting point, not a lock.
4. **A seeded ledger — after the user accepts the scaffold** — one `loop.state.jsonl` row
   per unit of work, at the accepted scaffold's entry stage, seeded per
   [`LOOP.md` §6, "Seed the work items"](LOOP.md#6-operating-the-loop). The row shape is
   defined in [`LOOP.md` §3](LOOP.md#3-work-item-row-shape) — do not re-declare it. Record
   the Q6 handoff in each row's free-form `metadata` (e.g. `metadata.handoff`); this slice
   ships no handoff template files, so do not reference a `handoff-templates/` directory as
   if it exists. Also stamp each row's `metadata` with the scaffold acceptance —
   `metadata.acceptedAt`, the ISO-8601 time the user accepted the scaffold — so the ledger
   carries on-disk proof it was seeded only after the acceptance gate. This reuses the
   free-form `metadata` channel: no top-level row field, no new file. The reference linter
   checks for this stamp in strict mode ([`LINTER.md`](LINTER.md)).

If stages or the unit-of-work decomposition change before the first iteration, discard the
draft ledger and reseed from the accepted scaffold.

To run it, follow [`prompts/run-one-iteration.md`](prompts/run-one-iteration.md).
