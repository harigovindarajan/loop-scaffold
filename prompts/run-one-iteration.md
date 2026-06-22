# Prompt: run-one-iteration

Advance the loop by exactly one step. Follow the three blocks below. This prompt adds
no rules of its own — it makes [`LOOP.md` §6](../LOOP.md#6-operating-the-loop)
executable. Everything normative lives in [`LOOP.md`](../LOOP.md); do not restate it.

---

## Input structure

```text
loop.json          # the scaffold (LOOP.md §2)
loop.state.jsonl   # the work-item ledger (LOOP.md §3)
```

Read both. Nothing outside these two files carries loop state.

---

## Canonical rules to follow

Do exactly one iteration, in this order — all per
[`LOOP.md` §6](../LOOP.md#6-operating-the-loop):

- **Pick** the first actionable item — `status` `pending` or `in-progress`; skip the
  rest. If none, the loop is idle — stop.
- **Run** its current stage by `kind` (`agent` / `checkpoint` / `verify`). If the item
  was `pending`, flip it to `in-progress` as part of this iteration's single write.
- **Classify** the outcome as exactly one failure-taxonomy code —
  [`LOOP.md` §4](../LOOP.md#4-failure-taxonomy).
- **Checkpoint reject special case** — if a `checkpoint` rejects and the outcome is the
  taxonomy's `retryable-defect`, do not persist the same-stage retry effect here. Use
  [`reopen-item`](reopen-item.md) instead; it performs this iteration's single write and
  routes the item back to the producing stage with the reviewer feedback attached.
- **Otherwise persist** the code's effect: apply it, set `updatedAt`, and on `pass`
  advance `stage` to `next` (resetting `attempts`), setting `status: done` and
  `stage: null` when `next` is `null`.
- **One transition only** — select one item, attempt one stage, write one line. This is
  the [`LOOP.md` §5](../LOOP.md#5-core-invariant) invariant.

---

## Output structure

Write back **exactly one** rewritten line to `loop.state.jsonl` — the whole line for
the single item you advanced, never a partial edit. Then the iteration ends; invoke
this prompt again to run the next one. You may stop after any completed iteration and
resume later from the same two files.
