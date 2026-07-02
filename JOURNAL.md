# JOURNAL.md

The optional **run history** for a loop. The state ledger (`loop.state.jsonl`) holds
*current state* — where every item is now; the journal holds *what happened* — how each
item got there. This is canon layered on [`LOOP.md`](LOOP.md); it references the kernel and
never re-declares it. A loop runs correctly without a journal ([`LOOP.md` §8](LOOP.md#8-out-of-scope-canon-territory));
it exists for metrics, audit, and replay.

## 1. The file

`loop.journal.jsonl` — the third (optional) file in a loop directory, sibling to
`loop.json` and `loop.state.jsonl`. One JSON object per line, and it is **append-only**:
every event appends exactly one line; existing lines are never edited or deleted. That
immutability is the point — the journal is the append-only counterpart to the
replace-in-place ledger ([`LOOP.md` §3](LOOP.md#3-work-item-row-shape)).

The ledger and the journal answer different questions and neither replaces the other:

| File | Mutability | Answers |
| --- | --- | --- |
| `loop.state.jsonl` | mutable table, replace-in-place | *Where is every item now?* |
| `loop.journal.jsonl` | append-only log | *What happened, in order?* |

## 2. Event shape

Each line is one event:

```jsonc
{
  "ts": "2026-07-02T14:03:11Z",   // ISO-8601; when the event was appended
  "seq": 42,                       // monotonic integer within this file; starts at 1, +1 per line
  "id": "item-003",                // the work item this event concerns; null for loop-level events
  "kind": "iteration",             // iteration | admin (see §3)
  "op": "pass",                    // taxonomy code or rewrite name (see §3)
  "from": {"status": "in-progress", "stage": "verify"},  // position before the event; null when the item did not exist yet
  "to":   {"status": "done", "stage": null},             // position after the event; null when the item was removed
  "attempts": 0,                   // attempts on the item's stage after the event
  "note": "verification passed"    // free-form; mirrors lastError.note when there is one
}
```

Field order is fixed as above, the same discipline the row follows
([`LOOP.md` §3](LOOP.md#3-work-item-row-shape)), so the log stays diffable and mechanically
checkable.

- `ts` is the append time. For an `iteration` event it equals the `updatedAt` the ledger
  write recorded; the journal keeps its own field so a line is self-contained.
- `seq` gives a total order for replay even if two events share a `ts` or a clock steps
  backward. It is **per file** — a batch shard's journal has its own `seq` run
  ([`BATCH-EXECUTION.md`](BATCH-EXECUTION.md)); merge by `ts` then per-shard `seq`.
- `from` / `to` carry only `status` and `stage` — the two fields that locate an item. Their
  values come from the closed sets in [`LOOP.md` §2–§3](LOOP.md#2-scaffold-shape); this doc
  does not re-list them.

## 3. `kind` and `op` — reference, don't restate

The event's meaning is carried by `kind` + `op`, both drawn from vocabulary the kernel
already defines. This doc points at those definitions rather than copying them
([`AUTHORING.md`](AUTHORING.md)):

- **`kind: "iteration"`** — the one persisted transition of an iteration
  ([`LOOP.md` §5](LOOP.md#5-core-invariant)). `op` is one of:
  - a failure-taxonomy code — `pass` | `retryable-defect` | `blocked-environment` |
    `human-exception` — exactly the closed set in
    [`LOOP.md` §4](LOOP.md#4-failure-taxonomy); or
  - `reopen` — the canon checkpoint-reopen route ([`prompts/reopen-item.md`](prompts/reopen-item.md)),
    which is that iteration's single write.
- **`kind: "admin"`** — an administrative rewrite that runs no stage
  ([`LOOP.md` §6](LOOP.md#6-operating-the-loop)). `op` is one of `seed` | `unpark` |
  `append` | `cancel`.

So `op` is a superset of the §4 taxonomy: every taxonomy code is a valid `op`, plus the
canon `reopen` and the four administrative names. A reader who knows `LOOP.md` already
knows every `op` value.

## 4. When to append

Append **one line per event, after the state write it records** — never before:

- Each iteration's single transition → one `iteration` line, appended after the row is
  persisted ([`LOOP.md` §6, "Persist the transition"](LOOP.md#6-operating-the-loop)). A
  reopen appends an `iteration` line with `op: "reopen"`.
- Each administrative rewrite (seed, unpark, append, cancel) → one `admin` line, appended
  after the rewrite.

Append-after-write keeps the ledger authoritative: if a crash lands between the two
writes, the ledger still holds correct state and the journal is missing at most one
*history* line — never state. Seeding a ledger of N rows appends N `seed` lines (one per
row); resuming an existing loop appends nothing until the next event.

## 5. Human-readable rendering (derived)

The JSONL is the durable form. A log-style view is a *projection* of it — compute it, do
not store it as the source of truth:

```
2026-07-02T14:03:11Z  item-003  iteration/pass     verify → done
2026-07-02T14:05:02Z  item-004  iteration/reopen   review → implement   (review: missing rate-limit check)
2026-07-02T14:06:20Z  item-005  admin/append       — → implement (pending)
2026-07-02T14:09:44Z  item-002  iteration/human-exception  verify → verify (needs-human)   (product call: keep the flaky caveat?)
```

Line format: `<ts>  <id>  <kind>/<op>  <from> → <to>  (<note>)`, with `—` for a null
`from`/`to`. Any renderer derives this from the fields, so the file on disk stays JSONL and
stays machine-readable for the linter and the metrics below.

## 6. Metrics (why it exists)

The [`STRATEGY.md`](STRATEGY.md) metrics read the journal, not the live ledger, because the
ledger retains no history:

- **Autonomous-run ratio** — `iteration` lines whose `op` is not a human touch ÷ all
  `iteration` lines.
- **Human-review touch count** — count of lines with `op` in `{human-exception, reopen}`
  plus `admin/unpark` lines whose `from.status` is `needs-human`.
- **Clean-resume rate** — replay `iteration` lines in `seq` order and confirm they
  reconstruct the ledger's current position for each `id`.

Because the ledger overwrites per-item counters (`attempts` resets on `pass` and on reopen),
these counts are only recoverable from the journal — that is the gap it closes.

## 7. Relationship to the linter

The shape-only linter ([`LINTER.md`](LINTER.md)) validates `loop.json` and
`loop.state.jsonl`; the journal is outside its current contract. A future strict check
could assert the journal is append-only-consistent with the ledger — for each `id`, the
`to` of its last `iteration`/`admin` line equals the item's current ledger position — but
that is not required to run a loop, and a loop with no journal is still fully conformant.
