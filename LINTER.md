# LINTER.md

> **Status: deferred to v1.1. Contract only — no linter ships in v1.**
> v1 of this repo is `LOOP.md` plus the canon docs. This file specifies what the
> reference linter *will* do, concretely enough to build later without re-deriving
> the loop format. The v1 formats in `LOOP.md` are designed to be checkable by exactly
> this contract.

## Purpose

The reference linter answers two questions about a loop, without running it:

1. **Is this loop well-formed?** — do the scaffold and state files conform to the kernel?
2. **Where is it?** — what is the current position and progress of the loop?

It is a *checker*, never an *executor* (see "Hard non-goal" below).

## Design constraints

- **Stateless.** The linter keeps no state of its own between runs. Everything it
  reports is derived fresh from the input files each invocation.
- **Dependency-light.** It needs only to read two text files and parse JSON / JSONL.
  No runtime engine, no network, no project-specific dependencies.
- **Optional.** A loop runs correctly without the linter. It is conformance assurance
  and progress reporting, not a required step in the iteration.

## Inputs

The linter reads the same two files the kernel defines — it does not re-declare their
shapes; it validates against `LOOP.md`:

- **Scaffold** — `loop.json` (see `LOOP.md` §2, "Scaffold shape").
- **State** — `loop.state.jsonl` (see `LOOP.md` §3, "Work-item row shape").

All field names, enums, and the stage/row shapes referenced below are defined in
`LOOP.md`. This file points at them rather than copying them.

## "Is this loop well-formed?" — conformance checks

The linter asserts, against the formats in `LOOP.md`:

**Scaffold (`LOOP.md` §2)**
- The scaffold parses as JSON and has a non-empty `stages` list.
- Every stage has `name`, `kind`, and `next`.
- Every `name` is unique within the scaffold.
- Every `kind` is in the closed set `agent | checkpoint | verify`.
- Every `next` is either `null` or the `name` of another stage (no dangling targets).
- Exactly the terminal stage(s) have `next: null`; the stage graph reaches a terminal
  from the entry stage (no cycles that can never terminate).

**State (`LOOP.md` §3, §4)**
- Each line parses as a JSON object (valid JSONL).
- Each row carries the full row shape: `id`, `status`, `stage`, `attempts`,
  `lastError`, `needsHuman`, `artifacts`, `updatedAt`, `metadata`.
- Every `id` is unique across the file.
- Every `status` is in the closed set `pending | in-progress | blocked | needs-human | done`.
- Every `stage` names a stage that exists in the scaffold, or is `null` for a `done` item.
- `lastError` is `null` or `{ code, note }` with `code` in the failure taxonomy
  (`LOOP.md` §4).
- Cross-field consistency: `needsHuman: true` iff `status` is `needs-human`;
  `attempts` is a non-negative integer; `updatedAt` is a valid ISO-8601 timestamp.

**Invariant (`LOOP.md` §5)**
- The invariant is structurally representable: each state line is a single row at a
  single stage. The linter flags any row that is internally inconsistent (e.g. a
  `done` row still pointing at a non-terminal stage). The one-transition-per-iteration
  rule governs *writes*; the linter checks the *resulting* state is well-formed, not the
  write history.

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
state:    OK (5 items)
position: 2 in-progress, 1 blocked, 0 needs-human, 2 done  → not idle
warnings: item-004 lastError.code "retry" not in failure taxonomy
```

Exact CLI shape, exit codes, and host language are intentionally unspecified here —
they are settled when the linter is built (see the deferred Outstanding Questions in the
origin requirements). What is fixed now is *what it reads* and *what it asserts*, both
anchored to `LOOP.md`.

## Hard non-goal

The linter **never executes a stage**. It does not do `agent` work, run `verify` checks,
or perform `checkpoint` reviews. It reads, validates, and reports. Anything that runs a
stage is an executor — explicitly outside this product's identity.
