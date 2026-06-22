# Prompt: reopen-item

Route a checkpoint-rejected item back to the stage that produced the rejected artifact.
This is the canon **reopen** behavior the kernel defers (`LOOP.md` §4): re-running a
`checkpoint` in place would only re-review the unchanged artifact, so repair has to happen
at the earlier stage that owns it. Everything normative about the row and the
single-transition rule lives in [`LOOP.md`](../LOOP.md); do not restate it here.

This is one iteration — it selects one item and writes one line, honoring the
[`LOOP.md` §5](../LOOP.md#5-core-invariant) invariant. Use it in place of a same-stage
re-attempt when a `checkpoint` rejects.

---

## Input structure

```text
loop.json          # the scaffold (LOOP.md §2)
loop.state.jsonl   # the work-item ledger (LOOP.md §3)
```

A `checkpoint` stage has just rejected the item you are advancing, with reviewer comments.
Read both files; nothing outside them carries loop state.

---

## Canonical rules to follow

- **Trigger only on a checkpoint rejection.** The selected item is `in-progress` on a
  `checkpoint` stage whose review rejected (a `retryable-defect`, per
  [`LOOP.md` §4](../LOOP.md#4-failure-taxonomy)). If the reviewer escalated to a
  `human-exception` instead, do not reopen — classify per the taxonomy.
- **Pick the target (producer) stage.** Default to the **nearest preceding `agent` stage**
  in `loop.json` — the stage that produced the reviewed artifact. If the loop documents an
  explicit reopen target for this checkpoint (a convention recorded alongside the loop, not
  a kernel field), use that instead.
- **Apply one transition** (the effect, per [`LOOP.md` §6](../LOOP.md#6-operating-the-loop)):
  - `status` stays `in-progress`.
  - `stage` ← the target producer stage.
  - `attempts` ← `0` (a fresh attempt at the producer stage).
  - `lastError` ← `{ "code": "retryable-defect", "note": <reviewer comments> }` — the
    closed-set code is preserved; the note carries the feedback.
  - Optionally also record the feedback in `metadata.reviewFeedback`.
  - `needsHuman` stays `false`; set `updatedAt` to now.
- **Reference, don't restate** — per [`AUTHORING.md`](../AUTHORING.md), the row fields and
  their meanings are defined in `LOOP.md` §3; point at it, do not re-declare it.

---

## Output structure

Write back **exactly one** rewritten line for the reopened item — the whole line, never a
partial edit. The item is now at the producer stage with the review feedback attached: the
next [`run-one-iteration`](run-one-iteration.md) picks it up there, the agent repairs the
artifact using the feedback, advances, and the checkpoint re-runs on the repaired artifact.
