# WALKTHROUGH.md — one item, end to end

A narrated trace of a v2 loop. Everything normative is in [`LOOP.md`](LOOP.md); this doc
only shows the rules happening. The pipeline is a small doc-migration:

```jsonc
{
  "name": "walkthrough", "version": 2, "items": ["tc-05", "tc-06"],
  "stages": [
    { "name": "draft",  "executor": "self", "produces": ["docs/{item}.md"],
      "gate": { "artifact": true } },
    { "name": "review", "executor": "reviewer-bot", "produces": ["reports/{item}.json"],
      "gate": { "run": "jq -e '.verdict==\"PASS\"' reports/{item}.json" },
      "onFail": "draft",
      "approval": { "graduation": { "afterCleanPasses": 2 } } },
    { "name": "verify", "executor": "self", "produces": [],
      "gate": { "run": "grep -q ok docs/{item}.md" }, "batchable": true }
  ],
  "policy": { "parallel": 2, "maxAttempts": 3 }
}
```

**Acceptance.** The user edits the draft plan, then commits it. That commit is the
construction gate ([`LOOP.md` §8](LOOP.md#8-operating-the-loop)) — before it, running
anything is a protocol violation.

**Derivation, not lookup.** `reconciler/loop status` computes positions
([`LOOP.md` §2](LOOP.md#2-position-is-computed-never-stored)): no pass-commit for
`loop(tc-05): draft ✓` exists, so tc-05 is *at draft, pending*. Nothing was read from
any state file, because there is none.

**A pass is a commit.** You write `docs/tc-05.md`, then `loop gate tc-05 draft`. The
artifact gate checks the file exists non-empty and commits it:

```
loop(tc-05): draft ✓
Gate: artifact: docs/{item}.md
Produces: docs/tc-05.md=9f2c…
```

Position now derives to *review* — because that commit exists, not because anyone
updated a row ([`LOOP.md` §4](LOOP.md#4-the-gate–commit-invariant)).

**A failed gate is not negotiable.** reviewer-bot writes
`reports/tc-05.json` with `"verdict": "FAIL"` and blocking findings.
`loop gate tc-05 review` exits non-zero. You classify it
([`LOOP.md` §5](LOOP.md#5-failure-taxonomy)): a fixable defect →
`loop note attempt tc-05 --stage review --note "missing assertion"`. The stage's
`onFail: draft` says the *draft* executor owns the fix — you repair `docs/tc-05.md`.

**Staleness routes the reopen.** The moment `docs/tc-05.md` changes, its hash no longer
matches the `Produces:` trailer of draft's pass-commit — position falls back to *draft*
(`edited-after-pass`). Re-gate draft; review then derives as *stale* (its recorded
`Inputs:` hash for `docs/tc-05.md` is outdated) and re-runs. No reopen bookkeeping —
the hashes did the routing.

**Approval, then graduation.** Review now passes mechanically, but the stage carries
`approval`, so tc-05 holds at *awaiting-approval* — the human's move, and `loop next`
will not pick it. The user checks the report:
`loop note approve tc-05 --stage review`. After 2 clean approvals uninterrupted by an
`attempt` on that stage, the human gate retires ([`LOOP.md` §6](LOOP.md#6-human-gates-and-graduation)) —
tc-06 and everything after pass on the mechanical gate alone. Trust was earned, not
hand-edited into the plan.

**Parking is the only written state.** Suppose tc-06's review needs a product decision:
`loop note park tc-06 --state needs-human --note "keep the flaky caveat?"` — one line in
`loop.notes.jsonl` ([`LOOP.md` §7](LOOP.md#7-the-notes-file-exceptions-only)). Picking
skips it until `loop note unpark tc-06 --note "user: keep it"`. If instead a retryable
defect burns `policy.maxAttempts`, the attempt note auto-parks it as `needs-human` — a
wedged item surfaces instead of starving the loop.

**Batching is legal.** Both items reach *verify*, which is `batchable`: `loop next`
emits **one** pick covering both. Each still gates individually — two empty pass-commits
(`produces: []`, so the message is the proof).

**Kill it anywhere; resume by reconciling.** Kill the session mid-write: the tree is
dirty, and `status` warns that ungated work is present, trusting only committed gates.
Nothing in memory was load-bearing — the next session reconciles and continues. The
run's history needs no separate journal; it *is* the log:

```
git log --oneline --grep='^loop('
e21f0c3 loop(tc-06): verify ✓
91b44d7 loop(tc-05): verify ✓
…
```
