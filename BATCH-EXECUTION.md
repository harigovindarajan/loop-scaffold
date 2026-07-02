# BATCH-EXECUTION.md

How to run multiple agents over a loop safely. This is canon layered on top of
[`LOOP.md`](LOOP.md); it does not change the kernel. The kernel remains the single-agent
linear loop, and this doc explains how to compose many independent kernel loops into a
batch run.

## 1. Boundary

Batch execution is an outer coordination protocol. Each worker still runs a normal loop by
following [`LOOP.md`](LOOP.md) and the prompts in [`prompts/`](prompts/). The coordinator
owns partitioning and merging; workers own only their assigned shard.

The hard safety rule is:

> No two agents write the same `loop.state.jsonl`.

This avoids locks, leases, and concurrent JSONL edits in the first batch design. Shared-file
concurrency is out of scope until there is a runtime or lock discipline.

## 2. When to use it

Use batch execution only after the pipeline is established enough that independent units can
run without constant human correction. Good candidates:

- Large mechanical migrations with many similar units.
- A scaffold that has already passed several single-agent iterations.
- Verification commands that can run independently per unit or per shard.

Do not use it while the pipeline is still being discovered, while checkpoints still reject
most outputs, or when items have shared side effects that make parallel execution unsafe.

## 3. Files

A batch run creates multiple complete loop directories. Each shard directory contains its
own copy of the scaffold and its own ledger:

```text
batches/<batch-id>/
  batch.json
  worker-001/
    loop.json
    loop.state.jsonl
  worker-002/
    loop.json
    loop.state.jsonl
```

`batch.json` is batch-level coordination state, not kernel loop state. Use this minimal
shape:

```jsonc
{
  "id": "batch-001",
  "source": {
    "scaffold": "../../loop.json",
    "state": "../../loop.state.jsonl"
  },
  "merge": {
    "target": "../../loop.state.jsonl",
    "policy": "replace-by-id"
  },
  "shards": [
    { "id": "worker-001", "path": "worker-001", "status": "ready" },
    { "id": "worker-002", "path": "worker-002", "status": "ready" }
  ]
}
```

Shard status is `ready`, `running`, `stopped`, or `merged`. `replace-by-id` means the merge
replaces the source row with the shard row carrying the same work-item id. A shard with a
malformed ledger does not merge. Work-item `id`s must be unique across **all** shards, not
just within one: the merge keys on `id`, so a cross-shard collision would overwrite the
wrong row.

Each worker directory is a valid standalone loop: if a worker stops, another agent can resume
that shard by reading only that shard's `loop.json` and `loop.state.jsonl`, plus any stage
instructions referenced by its scaffold.

## 4. Coordinator flow

The coordinator performs setup and merge work; it does not execute stages.

1. Start from an accepted scaffold and a set of work items.
2. Partition the work items into shard directories.
3. Copy the accepted scaffold into each shard as `loop.json`.
4. Seed each shard's `loop.state.jsonl` with only that shard's assigned items, following the
   seeding rule in [`LOOP.md` §6](LOOP.md#6-operating-the-loop).
5. Run the linter contract in [`LINTER.md`](LINTER.md) against every shard before dispatch.
6. Assign one worker agent to each shard directory.
7. Freeze the source ledger, if one exists, until the batch is merged. Do not run the source
   loop while shards are active. This freeze is a convention, not a lock — nothing enforces
   it; running the source loop (or a second coordinator) against the same ledger while
   shards are active can silently lose progress at merge time.
8. Update `batch.json` as shards move from `ready` to `running` to `stopped`.
9. When workers stop, lint each shard again and merge the resulting rows into the source or
   final ledger.
10. Mark merged shards as `merged` and lint the merged ledger.

Merge is an administrative batch operation, not a kernel iteration. It may replace multiple
rows because it is consolidating completed shard loops, not advancing one loop by one stage.

## 5. Worker flow

A worker receives exactly one shard directory. Inside that directory it behaves like a normal
single-agent runner:

- Read that shard's `loop.json` and `loop.state.jsonl`.
- Run [`prompts/run-one-iteration.md`](prompts/run-one-iteration.md) one iteration at a time.
- Use [`prompts/reopen-item.md`](prompts/reopen-item.md) for checkpoint rejections.
- Use [`prompts/resume-parked-item.md`](prompts/resume-parked-item.md) only when the block or
  human input for that shard has actually resolved.
- Stop when the shard is idle or when the coordinator's run budget is reached.

A worker must not edit another shard and must not edit the source ledger.

## 6. Failure handling

Shard rows use the statuses and taxonomy defined in [`LOOP.md`](LOOP.md). The coordinator does
not reinterpret them:

- Finished rows merge as finished rows.
- Actionable rows may be merged back for later single-agent or batch continuation.
- Parked rows stay parked until their block clears or human input arrives.
- A malformed shard does not merge; fix or rerun that shard first.

If any shard reports a systemic failure that likely affects other shards, stop dispatching new
work and return to single-agent diagnosis. Batch execution is for throughput, not for hiding
pipeline uncertainty.

## 7. Linter dependency

Batch execution should use the linter before dispatch, before merge, and after merge. Without
that checker, the coordinator has no cheap way to know whether each shard stayed conformant.

This makes [`LINTER.md`](LINTER.md) the prerequisite for safe batch execution, even though the
single-agent kernel can run without it.
