# LINTER.md

> **Status: ready to build. Contract only — no linter binary ships in this repo yet.**
> v1 of this repo is `LOOP.md` plus the canon docs. This file is the implementation
> contract for the reference linter: build it from this spec without re-deriving the
> loop format. The formats in `LOOP.md` are designed to be checkable by exactly this
> contract.

## Purpose

The reference linter answers two questions about a loop, without running it:

1. **Is this loop well-formed?** — do the scaffold and state files conform to the kernel?
2. **Where is it?** — what is the current position and progress of the loop?

An optional `--strict` mode adds a third, **was it constructed legitimately?** — a
presence check on the acceptance stamp the construction flow records (see that section
below). It stays off by default.

It is a *checker*, never an *executor* (see "Hard non-goal" below).

## Design constraints

- **Stateless.** The linter keeps no state of its own between runs. Everything it
  reports is derived fresh from the input files each invocation.
- **Dependency-light.** It needs only to read two text files and parse JSON / JSONL.
  No runtime engine, no network, no project-specific dependencies.
- **Optional.** A loop runs correctly without the linter. It is conformance assurance
  and progress reporting, not a required step in the iteration.

## Build target

The first linter should be the smallest useful checker:

```text
loop-lint [--json] [--strict] <loop.json> <loop.state.jsonl>
```

- Default output is human-readable, like the example below.
- `--json` emits the same result as structured data for scripts and batch coordinators.
- `--strict` adds the optional provenance check below; default runs shape checks only.
- Exit `0` when scaffold and state are conformant.
- Exit `1` when either file is readable but not conformant to this contract.
- Exit `2` for invocation or file-access failures.

The linter remains a checker only. It must not repair files, execute stages, call an agent,
or decide whether a domain-specific artifact is correct.

## Inputs

The linter reads the same two files the kernel defines — it does not re-declare their
shapes; it validates against `LOOP.md`:

- **Scaffold** — `loop.json` (see `LOOP.md` §2, "Scaffold shape").
- **State** — `loop.state.jsonl` (see `LOOP.md` §3, "Work-item row shape").

The optional run journal (`loop.journal.jsonl`, [`JOURNAL.md`](JOURNAL.md)) is **not** part
of this contract: a loop with no journal is fully conformant. A future strict check could
validate journal↔ledger consistency (`JOURNAL.md` §7); it is out of scope here.

All field names, enums, and the stage/row shapes referenced below are defined in
`LOOP.md`. This file points at them rather than copying them.

## "Is this loop well-formed?" — conformance checks

The linter asserts, against the formats in `LOOP.md`:

> **The literals below transcribe the closed sets and field lists defined in `LOOP.md`
> §2–§4.** This is the one place the kernel's vocabulary is intentionally duplicated — a
> checker must name what it checks. When the kernel's row shape, stage kinds, `status`
> set, or failure taxonomy changes, re-verify this section first: it is the repo's primary
> drift surface. Rules tagged *(derived)* are not stated verbatim in the kernel but follow
> from it.

**Scaffold (`LOOP.md` §2)**
- The scaffold parses as JSON and has a non-empty `stages` list.
- Every stage has `name`, `kind`, and `next`.
- If a stage carries the optional `instructions` field, it is a string or an array of
  strings (`LOOP.md` §2). Stages without it are still well-formed.
- If the scaffold carries an optional top-level `metadata`, it is an object (`LOOP.md`
  §2); its contents are free-form and not further validated.
- Every `name` is unique within the scaffold.
- Every `kind` is in the closed set `agent | checkpoint | verify`.
- Every `next` is either `null` or the `name` of another stage (no dangling targets).
- Exactly one stage is terminal (`next: null`); every non-terminal `next` names a stage
  that appears **later** in the list, so the pipeline is linear and acyclic and reaches
  the terminal from the entry stage (`LOOP.md` §2 — the kernel loop is single-agent
  linear; a row moving *backward* is the runtime `stage` value a reopen sets, not a
  scaffold `next` edge).

**State (`LOOP.md` §3, §4)**
- Each line parses as a JSON object (valid JSONL).
- Each row carries the full row shape: `id`, `status`, `stage`, `attempts`,
  `lastError`, `needsHuman`, `artifacts`, `updatedAt`, `metadata`.
- Every `id` is unique across the file.
- Every `status` is in the closed set `pending | in-progress | blocked | needs-human | done`.
- Every `stage` names a stage that exists in the scaffold, or is `null` for a `done` item.
- `lastError` is `null` or `{ code, note }` with `code` in the failure taxonomy
  (`LOOP.md` §4).
- Cross-field consistency: `needsHuman: true` iff `status` is `needs-human` *(derived)*;
  `attempts` is a non-negative integer; `updatedAt` is a valid ISO-8601 timestamp.
- Field order in each row matches the canonical order in `LOOP.md` §3 — the kernel
  declares it fixed and mechanically checkable, and JSONL is line-based text, so the
  linter reads it directly.
- A `done` row has `stage: null`, `attempts: 0`, and `lastError: null` *(derived)* — the
  kernel resets `attempts` to `0` and clears `lastError` on every `pass`, including the
  terminal one (`LOOP.md` §6, "Persist the transition").

**Invariant (`LOOP.md` §5)**
- The invariant is structurally representable: each state line is a single row at a
  single stage. The linter flags any row that is internally inconsistent (e.g. a
  `done` row still pointing at a non-terminal stage). The one-transition-per-iteration
  rule governs *writes*; the linter checks the *resulting* state is well-formed, not the
  write history.

## "Was it constructed legitimately?" — optional provenance check (`--strict`)

The default checks above validate file *shape* — they cannot tell whether the loop was
built through the interview and acceptance gate, or composed-seeded-and-run in one step
(the most common misuse; see [`INTERVIEW.md` §3](INTERVIEW.md#3-output-contract) and
[`prompts/construct-loop.md`](prompts/construct-loop.md)). `--strict` adds one provenance
check keyed off the acceptance stamp those docs require:

- Every seeded row carries `metadata.acceptedAt` (an ISO-8601 timestamp). A row missing it
  is reported as **seeded without recorded acceptance**.

This is a presence-and-format check, not a proof: the linter confirms the stamp exists and
parses, not that a human truly accepted the scaffold (a two-file design cannot prove that).
It is deliberately scoped — it stays a checker, reads only the same two files, never
executes a stage, and is off by default so a shape-only run is unchanged. In `--strict`, a
missing or malformed stamp makes the state non-conformant (exit `1`).

## "Where is it?" — progress report

From the state file alone (`LOOP.md` §3), the linter derives:

- Per item: its `status`, current `stage`, and `attempts`.
- Aggregate counts by `status` (how many `pending` / `in-progress` / `blocked` /
  `needs-human` / `done`).
- Which items are actionable (`pending` or `in-progress` — `LOOP.md` §6) vs. parked
  (`blocked` / `needs-human`) vs. finished (`done`).
- Whether the loop is idle (no actionable items remain).

This is a read of the ledger; it does not advance anything.

## What a conformance run looks like (directional)

```text
$ loop-lint loop.json loop.state.jsonl
scaffold: OK (3 stages, terminal: verify)
state:    ERROR (5 items)
position: 2 in-progress, 1 blocked, 0 needs-human, 2 done  → not idle
errors:   item-004 lastError.code "retry" not in failure taxonomy
```

Host language is intentionally unspecified. The fixed parts are the inputs, the checks,
the minimal CLI, and the exit-code contract above, all anchored to `LOOP.md`.

## Hard non-goal

The linter **never executes a stage**. It does not do `agent` work, run `verify` checks,
or perform `checkpoint` reviews. It reads, validates, and reports. Anything that runs a
stage is an executor — explicitly outside this product's identity.
