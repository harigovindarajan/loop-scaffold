# Prompt: resume-parked-item

Return a parked item — `blocked` or `needs-human` — to the loop once its block clears.
"Pick the next item" skips parked items forever (`LOOP.md` §6), so without this rewrite a
parked item is permanently dead. This performs the **unpark** rewrite defined in
[`LOOP.md` §6](../LOOP.md#6-operating-the-loop); everything normative lives there, do not
restate it.

This is **not an iteration.** Like seeding, it runs no stage and is not the single
transition of [`LOOP.md` §5](../LOOP.md#5-core-invariant) — it is an administrative rewrite
that makes the item actionable again at the same stage it was parked on.

---

## Input structure

```text
loop.json          # the scaffold (LOOP.md §2)
loop.state.jsonl   # the work-item ledger (LOOP.md §3)
```

The item to unpark is `blocked` or `needs-human`, and the condition that parked it has now
resolved. Read both files; nothing outside them carries loop state.

---

## Canonical rules to follow

- **Confirm the block has actually cleared** before rewriting. Unparking an item whose
  block is still live just re-parks it on the next iteration.
- **Blocked → in-progress.** When the environmental block has cleared, rewrite the
  `blocked` row to `status: "in-progress"`, same `stage`. Clear `lastError` or leave it as
  a record, per the loop's convention.
- **Needs-human → in-progress.** When the human input has arrived, rewrite the
  `needs-human` row to `status: "in-progress"`, `needsHuman: false`, same `stage`, and
  record what the human provided (e.g. in `metadata`). "Human input arrives" means the
  human supplied the missing decision, answer, or credential the stage was waiting on —
  for example, a `live-run` that hit a changed checkout flow, needed a secret only a human
  holds, or required a product call ("keep this assertion?") now has that answer in hand.
- **Same stage, one line.** Do not advance the stage and do not touch any other row; set
  `updatedAt` to now.
- **Reference, don't restate** — per [`AUTHORING.md`](../AUTHORING.md), the row fields and
  the `status` set are defined in `LOOP.md` §3; point at it, do not re-declare it.

---

## Output structure

Write back **exactly one** rewritten line for the unparked item — the whole line, never a
partial edit. The item is now actionable at the stage it was parked on; the next
[`run-one-iteration`](run-one-iteration.md) picks it up from there.
