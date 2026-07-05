# LOOP.md

The normative kernel of the portable agent loop, **version 2 — the artifact-graph
kernel**. If you are a coding agent, this file plus an accepted `loop.json` is
everything you need: derive where every item stands, advance the ones that are ready,
prove each advance with a gate, and commit each proof. State is **derived from artifacts
on disk** — you never maintain a parallel record of progress, so there is nothing to
drift and nothing to fake.

This file is the single source of truth for the kernel. Other docs reference it; none
may re-declare what is defined here. Voice is agent-first: the rules below are
operational and unambiguous. Follow them literally.

Requires a git repository. `git init` first if there isn't one.

---

## 1. The plan

One committed file, `loop.json`, declares the pipeline. It does not change mid-run
except by a new committed revision.

```jsonc
{
  "name": "unit-migration",
  "version": 2,
  "items": ["unit-01", "unit-02", "unit-03"],  // the work units, one id each
  "stages": [
    {
      "name": "contract",
      "executor": "self",                      // who runs it: "self" or a subagent name
      "produces": ["contracts/{item}.md"],     // artifact path(s); {item} = item id
      "gate": { "artifact": true },            // gate kinds: see §3
      "instructions": "docs/stages/contract.md"
    },
    {
      "name": "analyze",
      "executor": "analyzer-agent",
      "with": {                                // opaque executor inputs; see below
        "ruleset": "config/rules.json",
        "cache": ".loop-cache/analyses/"
      },
      "produces": ["analyses/{item}.json"],
      "gate": {
        "run": "jq -e '.status==\"completed\"' analyses/{item}.json",
        "expects": "analyzer report JSON with a top-level status field"   // see §3
      },
      "batchable": { "max": 3 }                // one call covers ≤3 items; bare true = no max
    },
    {
      "name": "rewrite",
      "executor": "rewriter-agent",
      "produces": ["out/{item}.txt"],
      "gate": { "run": "scripts/lint out/{item}.txt" },
      "timeoutMinutes": 20                     // per-stage override of policy.stageTimeoutMinutes
    },
    {
      "name": "review",
      "executor": "reviewer-agent",
      "produces": ["reports/{item}-review.json"],
      "gate": { "run": "jq -e '.verdict==\"PASS\"' reports/{item}-review.json" },
      "onFail": "rewrite",                     // reopen target: whose executor fixes it
      "approval": { "graduation": { "afterCleanPasses": 3, "resetOn": "any-attempt" } } // §6
    },
    {
      "name": "verify",
      "executor": "self",
      "produces": [],                          // gate-only stage; test results are ephemeral
      "gate": { "run": "scripts/test {item}" }
    }
  ],
  "policy": {
    "parallel": 2,               // max items in flight at once (default 1)
    "maxAttempts": 3,            // same-stage retry budget before parking (default 3)
    "stageTimeoutMinutes": 45    // optional executor wall-clock budget; unset = no timeout (§5)
  }
}
```

Stage contract: `name` (unique), `executor`, `with` *(optional; see below)*, `produces`
(may be empty for gate-only stages; entries may be globs; slice-shaped items list many
paths), `gate` (required), `instructions` *(optional path(s) to the stage's runbook)*,
`batchable` *(optional; `true` or `{ "max": N }`)*, `timeoutMinutes` *(optional; see
§5)*, `onFail` *(optional, an earlier stage's name)*, `approval` *(optional; see §6)*.
Stages run in list order per item.

A stage's **inputs** for an item are the earlier stages' `produces` paths for that item
(`{item}` substituted, globs expanded). They are what the stage builds on, what the
gate-pass commit hashes (§4), and what staleness compares against (§2).

`with` declares extra executor inputs the pipeline alone cannot express: a map of
string keys to paths or values, `{item}` substitutable. The map is passed **verbatim**
to the executor at §8 step 3; the kernel never interprets the keys, and `with` values
are not inputs in the sense above — they join neither the hashed input set nor
staleness comparison (§2). A path named in `with` that the executor *writes* (a cache,
a scratch directory) is gitignored by convention (§4).

---

## 2. Position is computed, never stored

```
position(item):  the first stage (in order) whose gate does not pass or is stale
done(item):      every stage's gate passes and none is stale
stale(stage):    any input's current hash differs from the hash recorded by the
                 stage's gate-pass commit (§4) — content hashes, never mtimes
```

Recompute positions from disk at the start of every session and whenever artifacts
change. There is no status field to update. Staleness is what routes a reopen: when a
`review` failure is repaired by editing an earlier stage's artifact (`onFail`), every
downstream gate goes stale and the item's position falls back by itself.

## 3. Gates

A gate is the proof a stage is complete. Three kinds:

- `{ "artifact": true }` — every path in `produces` exists and is non-empty.
- `{ "run": "<command>" }` — the command exits 0 (`{item}` substituted). The command is
  the authority: a stage whose gate fails is not done, whatever anyone wrote anywhere.
- `approval` on a stage adds a **human gate** on top of its mechanical gate (§6).

A gate may carry an optional `expects`: a one-line human-readable description of the
artifact shape the gate asserts on. It has no runtime effect — it exists so a mismatch
between an executor's output contract and the gate is visible at plan review
([`CONSTRUCT.md`](CONSTRUCT.md) contract check), not discovered at execution.

Prefer `run` gates. A gate expressed as prose is a wish.

A gate is evaluated when its stage is executed, and re-evaluated only when the stage is
stale or its artifacts changed since the pass-commit; an unchanged committed pass is
trusted. This is what keeps expensive gates (a full test run) from re-running on every
reconcile.

## 4. The gate–commit invariant

> **No work builds on an ungated artifact, and no gate-pass goes uncommitted.**

When a gate passes, commit the produced artifacts before any dependent work starts:

```
loop(<item>): <stage> ✓
Gate: <the command that passed>
Inputs: <path>=<sha256> for each input (§1)
Took: <minutes>m        (optional — wall-clock from executor-call start, orchestrator-measured)
```

The optional `Took:` trailer is what makes duration a `git log` query instead of
transcript archaeology; the pass-commit timestamp alone only marks the end.

A gate-only stage (empty `produces`) records its pass as an **empty commit** — the
message is the proof. Artifacts present on disk with no pass-commit are **ungated**:
position stands at that stage until the gate is run and committed.

The git log is the run history — timestamps, diffs, and order come for free, and
metrics are `git log --grep='^loop(' ` queries. A dirty tree at reconcile time means
unproven work: re-run the affected gates before trusting positions. This rule has no
exemptions. A path an executor merely *writes to* as scratch (a cache directory,
typically named in a stage's `with` map, §1) is kept out of the tree by convention
instead: the operator gitignores it in the loop repo — elicited per `with` entry during
construction ([`CONSTRUCT.md`](CONSTRUCT.md)).

Within this invariant, batching and parallelism are legal: one executor call may cover
several `batchable` items, and up to `policy.parallel` items may be in flight — provided
no stage consumes an artifact whose gate hasn't passed and been committed. Stages that
mutate a **shared** artifact must serialize on that artifact; disjoint items need no
coordination because there is no shared state file to contend on.

**Partial banking.** When a batch executor call completes some items' artifacts and
then fails, stalls, or is killed, run each member item's gate over whatever the batch
left on disk, and commit each pass individually — *before* writing the attempt note
(§7). A batch's death never discards a member item's proven work; banked work left
uncommitted is exactly the ungated-artifact state this invariant forbids.

## 5. Failure taxonomy

Every gate or executor failure resolves to exactly one code — a closed set:

| Code | Meaning | Effect |
| --- | --- | --- |
| `pass` | Gate passed. | Commit per §4; position advances by derivation. |
| `retryable-defect` | Fixable by trying again. | Re-attempt: the `onFail` stage's executor if set, else the same stage. Append an `attempt` note (§7); at `policy.maxAttempts`, park as `needs-human`. |
| `blocked-environment` | External block; no progress possible until something outside changes. | Park as `blocked` with the reason (§7). |
| `human-exception` | Only a human can decide. | Park as `needs-human` with the question (§7). |

A *transient* fault a retry may clear (flaky network, timeout) is `retryable-defect`;
reserve `blocked-environment` for blocks needing external change. **Never mark an item
past a failing gate** — if the gate cannot pass for environmental reasons, that is a
park, not a pass.

**Executor timeouts.** `policy.stageTimeoutMinutes` (global) and a stage's
`timeoutMinutes` (override) bound the wall-clock of one executor call, measured by the
orchestrator — the kernel stays stateless; the note is the record. Both are optional;
unset means no timeout. On expiry, classify as `retryable-defect`: apply partial
banking (§4), append an `attempt` note whose text records the timeout (§7), and
re-attempt within `policy.maxAttempts`.

## 6. Human gates and graduation

A stage with `approval` is not passed until a human approves the produced artifact —
recorded as an `approve` note (§7) — in addition to its mechanical gate.
`graduation.afterCleanPasses: N` retires the human gate after N consecutive approvals
uninterrupted by an `attempt` on that stage: from then on the mechanical gate alone
suffices. This is how a loop earns unattended operation instead of a human editing the
plan mid-run.

`graduation.resetOn` (optional) sets what interrupts the count:

- `"any-attempt"` (default) — any `attempt` note on the stage resets it.
- `"new-findings"` — the human at the approval gate decides the weight of intervening
  attempts: an `approve` note carrying `"newFindings": false` states that the attempts
  since the previous approval surfaced nothing new (e.g. only a reclassification of
  already-reviewed facts), and the count continues instead of restarting. An approval
  without that field resets and restarts the count as usual.

The judgment is the human's alone, recorded in the note — the kernel never inspects a
stage's artifacts, and no executor's report format is assumed, to make this call.

## 7. The notes file (exceptions only)

Progress is never written — it is derived. The only writes go to an append-only
`loop.notes.jsonl`, one JSON object per line, covering exactly what disk state cannot
show:

```jsonc
{"ts": "…", "item": "tc-05", "op": "park",    "state": "needs-human", "note": "duplicate placeholder; which form wins?"}
{"ts": "…", "item": "tc-05", "op": "unpark",  "note": "user: scope to the login form"}
{"ts": "…", "item": "tc-07", "op": "attempt", "stage": "rewrite", "n": 2, "took_min": 12, "note": "lint: unresolved reference"}
{"ts": "…", "item": "tc-03", "op": "approve", "stage": "review", "newFindings": false, "note": "reclassification only; streak continues (§6)"}
{"ts": "…", "item": "tc-09", "op": "cancel",  "note": "test retired upstream"}
```

`op` ∈ `park | unpark | attempt | approve | cancel` — closed set. A parked item is
skipped by picking until an `unpark` note releases it. A cancelled item is skipped
permanently. Attempt counting toward `policy.maxAttempts` considers only `attempt` notes
newer than the stage's last pass-commit. Passes never appear here; passes are commits.
An `attempt` note may carry an optional `"took_min": N` (wall-clock of the failed
executor call); an `approve` note may carry `"newFindings": false` (§6).

Because a missed attempt note undercounts `maxAttempts` and corrupts graduation
reasoning, the note's *existence* must not depend on orchestrator discipline: when the
reconciler CLI is in use, `loop run` wraps executor and gate and machine-writes the
attempt note on any non-pass outcome — the orchestrator only adds color to the text.

**Hygiene.** Loop artifacts — the plan, notes, stage instructions, and executor
prompts — reference secret-bearing values indirectly (an environment-variable name, a
symbolic reference into a committed data module), never literal credentials, tokens,
or personal identifiers. These artifacts are committed and quoted into prompts; a
literal secret placed in one propagates beyond the reach of any executor's own output
hygiene. Construction flags violations before acceptance
([`CONSTRUCT.md`](CONSTRUCT.md)).

## 8. Operating the loop

**Construction gate (once).** Execution may not begin until `loop.json` exists *and is
committed* — drafted by you (the elicitation and composition flow is
[`CONSTRUCT.md`](CONSTRUCT.md)), edited and accepted by the user; the plan's commit is
the acceptance. Deriving a plan and executing it in one uncommitted breath is the misuse
this gate exists to stop.

**Then, repeatedly:**

1. **Reconcile** — derive every item's position (§2); skip parked and cancelled items.
2. **Pick** — up to `policy.parallel` items whose current stage's inputs all exist and
   are gated. Same-stage `batchable` items are split into up to `policy.parallel`
   concurrent executor calls of at most `batchable.max` items each — batching and
   parallelism compose rather than compete. Bare `batchable: true` means one call, no
   max.
3. **Execute** — run the stage's executor with its `instructions`, the items' inputs,
   and the stage's `with` map passed verbatim (`{item}` substituted, keys
   uninterpreted; §1), within the stage's effective timeout (§5).
4. **Gate** — run the gate; classify the outcome (§5).
5. **Persist** — commit on `pass` (§4); otherwise write the one matching note (§7).
6. Stop when no item is actionable: everything is `done`, parked, or cancelled. Report
   parked items and why.

You may stop after any step-5 boundary; nothing in memory is load-bearing. To resume:
reconcile. Work discovered mid-run = append the item id to `loop.json`'s `items` in a
committed revision.

The optional reconciler CLI ([`reconciler/`](reconciler/)) mechanizes reconcile, pick,
gate-and-commit, and note-writing (`loop status` / `next` / `gate` / `note` / `run`); it
adds no rules to this file, and a loop run without it is equally conformant.

---

*Everything else — pipeline shapes, elicitation, worked examples, the reconciler CLI —
is canon layered on this file and may not restate it.*
