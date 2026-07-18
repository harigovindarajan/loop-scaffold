# Prompt: run-one-pick

Advance the loop by exactly one pick. Everything normative is in
[`LOOP.md`](../LOOP.md); this prompt adds no rules.

1. **Reconcile** — derive positions from the plan, the pass-commits, and
   `loop.notes.jsonl` ([`LOOP.md` §2](../LOOP.md#2-position-is-computed-never-stored)),
   or run `reconciler/loop status`.
2. **Pick** — the next pick per [`LOOP.md` §8](../LOOP.md#8-operating-the-loop) (or
   `reconciler/loop next`). If none, the loop is idle: report parked items and stop.
3. **Execute** — do the pick's stage for its item(s) with the stage's `executor` and
   `instructions`, passing its `with` map verbatim and respecting its effective
   timeout ([`LOOP.md` §8](../LOOP.md#8-operating-the-loop)), building only on
   committed, gated inputs.
4. **Gate and persist** — for each item, run `reconciler/loop gate <item> <stage>`
   (commits the proof on pass). On failure, classify per
   [`LOOP.md` §5](../LOOP.md#5-failure-taxonomy) and record it:
   `reconciler/loop note attempt|park <item> …`.

Then stop. Invoke this prompt again for the next pick; resuming later needs nothing but
the repo.
