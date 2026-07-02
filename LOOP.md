# LOOP.md

The normative kernel of the portable agent loop. If you are a coding agent, this
file plus an **accepted scaffold and a seeded ledger** is everything you need to run a
**single-agent linear loop**: advance one stage at a time, persist each transition, and
stop or resume cleanly. Turning a task *into* work items is gated and goes through the
construction canon ([`INTERVIEW.md`](INTERVIEW.md),
[`prompts/construct-loop.md`](prompts/construct-loop.md)) — see §6; reading this kernel
alone lets you **run** an already-constructed loop, not compose one.

This file is the single source of truth for the kernel. Other canon docs (pipeline
shapes, checkpoints, durable handoffs, worked examples, multi-agent loops) reference
this file; they never re-declare what is defined here. If you only read this file,
you can still run a correct loop.

Voice is agent-first: the rules below are operational and unambiguous. Follow them
literally.

---

## 1. What you operate on

A loop has exactly two persisted files:

- **A scaffold** (`loop.json`): the pipeline — an ordered list of named stages. It is
  declared up front and does not change mid-run.
- **A state file** (`loop.state.jsonl`): the work-item ledger — one JSON object per
  line, one line per work item. This is the only place loop state lives.

You read both to decide what to do; you write the state file to record what you did.
You never write the scaffold during a run.

---

## 2. Scaffold shape

`loop.json` declares the stages every work item passes through, in order.

```jsonc
{
  "name": "example-loop",
  "stages": [
    { "name": "implement", "kind": "agent",      "next": "review"  },
    { "name": "review",    "kind": "checkpoint", "next": "verify",
      "instructions": "docs/review-rules.md" },
    { "name": "verify",    "kind": "verify",     "next": null      }
  ]
}
```

A **stage** has three required fields and one optional fourth — this is the stage
contract:

- `name` — unique stage identifier, referenced by a work item's `stage`.
- `kind` — one of a closed set:
  - `agent` — you do the work for this stage.
  - `checkpoint` — the named artifact is reviewed; the review may pass or reject.
  - `verify` — a defined check decides pass or fail.
- `next` — the `name` of the stage to advance to on success, or `null` for the
  terminal stage (after it, the item is `done`).
- `instructions` *(optional)* — a path, or an array of paths, to the docs that define
  this stage's behavior (its runbook — e.g. review rules a `checkpoint` enforces, or the
  rule sets a `verify` checks against). The kernel does not interpret their contents;
  they make a resumed stage self-contained. Stages without dedicated docs omit the field.

The first stage in the list is the entry stage for every new work item.

The scaffold may also carry an optional top-level **`metadata`** object — free-form, and
not interpreted by the kernel, exactly like a work item's `metadata` (§3). It is the home
for loop-level settings a run needs but the kernel ignores: the verification note (what
"pass" means for the terminal `verify`), the failure-intent guidance, reopen targets, and
the retry budgets (`maxAttempts`, `maxReopens`). Canon defines those keys ([`INTERVIEW.md` §3](INTERVIEW.md#3-output-contract),
[`prompts/reopen-item.md`](prompts/reopen-item.md)); the kernel only reserves the channel.
Omit it when the loop needs none.

---

## 3. Work-item row shape

Each line in `loop.state.jsonl` is one work item:

```jsonc
{
  "id": "item-001",          // unique, stable identifier for this work item
  "status": "in-progress",   // pending | in-progress | blocked | needs-human | done
  "stage": "implement",      // name of the current stage; null once status is "done"
  "attempts": 1,             // times the current stage has been attempted
  "lastError": null,         // { "code": <taxonomy>, "note": <string> } or null
  "needsHuman": false,       // true when only a human can unblock this item
  "artifacts": [],           // paths to durable handoff artifacts produced so far
  "updatedAt": "2026-06-21T17:30:00Z",  // ISO-8601 timestamp of the last transition
  "metadata": {"acceptedAt": "2026-06-21T17:25:00Z"}  // free-form (kernel does not interpret it); a seeded row carries the construction-flow acceptance stamp — INTERVIEW.md §3
}
```

`status` is a closed set:

- `pending` — created, not yet started.
- `in-progress` — actively moving through stages.
- `blocked` — cannot proceed right now; environmental, may clear later.
- `needs-human` — requires a human decision; `needsHuman` is `true`.
- `done` — passed the terminal stage; no further work.

Write the **whole line** on every transition. Never partially edit a line. Field
order is fixed as above so diffs stay readable and the line is mechanically checkable.

The state file is a **mutable table, not an append-only log**: each work item has exactly
one line, and a transition **replaces that item's existing line in place** (write to a
temp file and rename over the original so a crash cannot leave a half-written line). It
holds *current state* only — for a durable record of what happened across a run, see §8
(run history is canon, not kernel).

---

## 4. Failure taxonomy

Every stage attempt resolves to exactly one of these codes. This is a closed set.

| Code | Meaning | Effect on the item |
| --- | --- | --- |
| `pass` | The stage succeeded. | Advance to `next` (or `done` if `next` is `null`). |
| `retryable-defect` | A defect you can fix by trying again. | Stay on the same stage; `attempts += 1`; status stays `in-progress`. |
| `blocked-environment` | Something outside the work blocks progress (missing dep, unavailable service). | Status → `blocked`; record `lastError`; stop touching this item until the block clears. |
| `human-exception` | A decision or action only a human can take. | Status → `needs-human`; set `needsHuman: true`; record `lastError`. |

A `checkpoint` rejection is a `retryable-defect` against the rejected stage unless the
reviewer escalates it to a `human-exception`. A `verify` failure is a
`retryable-defect` unless its cause is environmental (`blocked-environment`). A
*transient* environmental fault a re-attempt may clear (a flaky network call, a momentary
timeout) is a `retryable-defect`; reserve `blocked-environment` for a block that needs an
external change before any progress is possible.

**Who repairs the artifact depends on the stage kind.** `agent` and `verify` re-attempts
do work, so a re-attempt may fix the artifact in place. A `checkpoint` only *reviews* and
owns no edits — re-running it would just re-review the unchanged artifact — so a rejected
checkpoint is **not** repaired in place: the item is routed back to the stage that produced
the artifact by the **reopen** behavior defined in canon (`prompts/reopen-item.md`), not
here. A scaffold containing `checkpoint` stages is therefore fully runnable only together
with that reopen canon; the kernel on its own runs `agent`/`verify` pipelines end to end.

**Retries are bounded.** A stage that keeps resolving to `retryable-defect` is not
retried forever: at the loop's retry budget it escalates to `human-exception`
(status → `needs-human`) so a wedged item surfaces instead of starving the loop. The
budget is a loop-level setting the scaffold's `metadata` carries (§2), with a safe default
when absent so a starter scaffold with no `metadata` is still bounded: `metadata.maxAttempts`
caps same-stage re-attempts and `metadata.maxReopens` caps checkpoint reopen ping-pong
(`prompts/reopen-item.md`) — canon defaults both to 3, and the failure-intent guidance
(§2) may raise or lower them.

`retryable-defect` always re-attempts the **same** stage — the kernel never reopens an
item to an earlier stage. When a defect surfaced at one stage is rooted in an earlier
one (e.g. a `verify` failure caused by bad `agent` output), the re-attempt fixes it in
place. Reopening to a specific earlier stage is the richer behavior that lives in the
canon reopen path above, not this kernel.

---

## 5. Core invariant

**One row, one stage, one persisted transition per iteration.**

Each iteration you select exactly one work item, attempt exactly one stage, and write
exactly one updated line to the state file. Never advance two items, never skip a
stage, never write more than one transition in a single iteration. This invariant is
what makes a loop resumable and checkable.

---

## 6. Operating the loop

### Seed the work items (once, before the first iteration)

**Precondition — an accepted scaffold.** Seeding presupposes a `loop.json` whose stages
the user has accepted, produced by the interview and construction flow
([`INTERVIEW.md`](INTERVIEW.md), [`prompts/construct-loop.md`](prompts/construct-loop.md)).
If you hold a task but no accepted scaffold, you are **not ready to seed** — construct the
scaffold and get it accepted first, then return here. Reading this kernel alone lets you
*run* an already-constructed loop; it does not authorize composing a scaffold, seeding a
ledger, and executing a stage in one step. Doing so is the most common way the loop is
misused.

Turn the task into work items. Decompose the task into the smallest units that each
make sense to carry through the pipeline independently, and for each one append a row to
`loop.state.jsonl` with `status: "pending"`, `stage` set to the scaffold's entry stage
(the first stage in `loop.json`), `attempts: 0`, `lastError: null`, `needsHuman: false`,
empty `artifacts`, `updatedAt` now, and `metadata` carrying the construction flow's
acceptance stamp (`acceptedAt` — [`INTERVIEW.md` §3](INTERVIEW.md#3-output-contract)). If
`loop.state.jsonl` already has rows (you are resuming), skip seeding — the ledger already
exists.

Seeding is setup, not an iteration: it does not run a stage. The iteration loop below
begins once at least one `pending` row exists.

### Pick the next item

Scan `loop.state.jsonl`. Choose the **first** item that is actionable, where actionable
means `status` is `pending` or `in-progress`. Skip `blocked`, `needs-human`, and `done`
items. If no item is actionable, the loop is idle — stop.

(Order is top-to-bottom in the file; this makes selection deterministic and the loop
replayable. The kernel selects in file order only; any other ordering policy is canon,
not kernel — see §8.)

### Run one stage

If the selected item is `pending`, set its `status` to `in-progress` — this is the first
attempt on it, and the flip is part of this iteration's single write. Then look up its
current `stage` in the scaffold and act per `kind`:

- `agent` — do the work this stage describes.
- `checkpoint` — review the named artifact; decide pass or reject.
- `verify` — run the defined check; decide pass or fail.

Resolve the attempt to exactly one failure-taxonomy code (Section 4).

### Persist the transition

Apply the code's effect from Section 4 to the item, set `updatedAt` to now, and write
the whole line back to `loop.state.jsonl`. On `pass`, set `stage` to the stage's `next`,
reset `attempts` to `0` for the new stage, clear `lastError` to `null` (the prior failure
is resolved — a passing row carries no stale error), and if `next` is `null` set `status`
to `done`. This single write is the iteration's one persisted transition.

Then the iteration ends. Begin the next iteration from "Pick the next item".

### Stop and resume

You may stop after any completed iteration — the state file fully describes where every
item is. To resume, read `loop.state.jsonl` and `loop.json` and continue from "Pick the
next item". No in-memory state carries across a stop: these two files fully describe the
loop's **state and position**. *Executing* a resumed stage may also need that stage's
runbook — the docs named in its `instructions` (§2), or the adapter and task docs — which
say what the stage does, not where the loop is.

### Unpark (return a parked item to the loop)

A `blocked` or `needs-human` item is skipped by "Pick the next item" forever, so it needs
an explicit way back. When the block clears, rewrite the row:

- A `blocked` item whose environmental block has cleared → `status: "in-progress"`, same
  `stage`.
- A `needs-human` item once the human input arrives → `status: "in-progress"`,
  `needsHuman: false`, same `stage`, recording what was provided (e.g. in `metadata`).

This rewrite is setup, not an iteration — like seeding, it runs no stage and is not the
single transition of Section 5. The item then resumes from "Pick the next item" at the
stage it was parked on. The companion prompt is `prompts/resume-parked-item.md`.

### Administrative rewrites (not iterations)

Seeding and unparking are both **administrative rewrites**: ledger writes that run no
stage and are *not* the single transition of Section 5. Two more belong to the same
category and are equally allowed between iterations:

- **Append an item** — when work is discovered mid-run, append a fresh `pending` row at
  the entry stage (seed shape above). Seeding is "once, before the first iteration" only
  in the sense that you do not re-seed the whole ledger on resume; adding a newly found
  unit later is a normal administrative rewrite.
- **Cancel an item** — when a unit becomes obsolete, remove its line (there is no
  "won't-do" status; the closed `status` set stays closed). If you keep run history,
  journal the removal (§8) so the cancellation is not silently lost.

An administrative rewrite may touch one row and never runs a stage, so it is exempt from
the one-transition invariant. Everything the iteration loop does (pick → run → persist)
stays governed by Section 5.

---

## 7. Adapter stub

An adapter wires a specific agent to this protocol. It is thin — it points at this file
and supplies the runtime details; it never restates the rules above.

```text
# adapter (generic)
0. Read LOOP.md (this file), loop.json (scaffold), loop.state.jsonl (state).
   If the ledger is empty, seed from the accepted scaffold (not straight from a task —
   construction is gated) → Section 6, "Seed the work items".
1. Pick the next actionable item        → Section 6, "Pick the next item".
2. Run its current stage                → Section 6, "Run one stage".
3. Classify the outcome                 → Section 4, failure taxonomy.
4. Persist exactly one transition       → Section 6, "Persist the transition".
5. Stop, or loop to step 1.
```

Concrete adapters (claude / codex / opencode) live alongside the canon and only add
agent-specific invocation details on top of these six steps. The optional `runner/`
driver plus a filled-in iteration prompt *is* one such adapter in fresh-session form: it
discharges these six steps by spawning one session per iteration. A same-session adapter
instead follows the six steps inline in one long-lived session. Either way the steps —
and every rule they reference — are unchanged.

---

## 8. Out of scope (canon territory)

The kernel is deliberately the minimal runnable subset. The following are **not** defined
here and carry no normative meaning in this file — they live in the referencing canon
docs:

- Pipeline shapes and starter topologies for specific kinds of work.
- Checkpoint review depth, blocking vs non-blocking gates, reopen targets.
- Durable handoff artifact templates (contract, implementation plan, review notes,
  verification report).
- Worked examples and migrations, including the narrated trace in
  [`WALKTHROUGH.md`](WALKTHROUGH.md).
- Multi-agent and non-linear loops — the kernel covers the single-agent linear case only.
- Alternate item-ordering policies — the kernel selects in file order (§6); any other
  ordering (priority, dependency, cost) is canon.
- Run history and audit journals — the state ledger holds *current state* only. A durable
  record of *what happened* across a run (for metrics, replay, or audit) is the optional
  append-only journal defined in canon ([`JOURNAL.md`](JOURNAL.md)) — never made by turning
  the state file itself append-only.

If you need any of the above, follow the canon doc that references this kernel. Do not
infer rules for them from this file.
