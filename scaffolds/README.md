# scaffolds/

Starter scaffolds and an example ledger for the portable agent loop. Copy a starter to
begin a loop; this directory does not define the formats — [`LOOP.md`](../LOOP.md) does.

To have an agent build a loop tailored to your task instead of copying a starter, follow
[`prompts/construct-loop.md`](../prompts/construct-loop.md) (it composes one via the
[`INTERVIEW.md`](../INTERVIEW.md) interview).

## What's here

| File | What it is |
| --- | --- |
| `loop.minimal.json` | The leanest real pipeline: `implement → verify`. A starting `loop.json`. |
| `loop.checkpoint.json` | The same with a review gate: `implement → review → verify`. A starting `loop.json`. |
| `loop.state.example.jsonl` | A **sample** ledger showing the row shape at rest — not live state. |

## The two file formats

A loop has exactly two files. For what the fields mean, follow the links — this doc does
not re-declare them.

- **`loop.json`** — the scaffold: a single JSON object naming the ordered stages every
  work item passes through. The stage contract (`name`, `kind`, `next`) and the stage
  kinds (`agent`, `checkpoint`, `verify`) are defined in
  [`LOOP.md` §2](../LOOP.md#2-scaffold-shape). A stage may also carry an optional
  `instructions` field (a path or array of paths to its runbook docs) — a self-containment
  aid for resuming, defined in `LOOP.md` §2. The two starters here omit it, showing it is
  optional; the two starters are valid `loop.json` files — copy one.
- **`loop.state.jsonl`** — the ledger: one JSON object per line, one line per work item.
  The row shape and the meaning of `status`, `stage`, and `attempts` are defined in
  [`LOOP.md` §3](../LOOP.md#3-work-item-row-shape). `loop.state.example.jsonl` shows that
  shape across a `done`, an `in-progress`, and a `pending` row.

## Which starter to pick

- **`loop.minimal.json`** when the work just needs doing and checking — an `agent` stage
  produces the artifact, a `verify` stage decides pass or fail.
- **`loop.checkpoint.json`** when the output should be reviewed before it is verified. The
  only difference is one inserted `checkpoint` stage — that contrast is the point: a
  `checkpoint` drops in at any position without any special handling. Add or remove
  checkpoints to fit your pipeline.

## How to start a loop

1. Copy a starter to your working directory as `loop.json`:
   `cp scaffolds/loop.minimal.json loop.json`.
2. Seed `loop.state.jsonl` from your task — one row per work item, each at the scaffold's
   entry stage. The exact seeding rule is
   [`LOOP.md` §6, "Seed the work items"](../LOOP.md#6-operating-the-loop).
3. Run iterations per [`LOOP.md` §6](../LOOP.md#6-operating-the-loop). Stop and resume
   anytime — the ledger fully describes where every item is.

`loop.state.example.jsonl` is a reference only. Create your own `loop.state.jsonl`; do not
append to the example.
