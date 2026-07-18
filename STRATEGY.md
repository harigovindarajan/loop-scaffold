---
name: Relay
last_updated: 2026-07-18
---

# Relay Strategy

## Target problem

A genuinely autonomous coding job — like migrating a Selenium suite to Playwright
across ~2,000 tests — runs for a day or two, outliving any single agent's context
window. No coding agent's native loop can carry that end-to-end: as context
accumulates the orchestrator degrades and loses the thread, it can't be trusted
unattended until confidence is earned, and an inadvertent interruption loses the work.
The crux is long-horizon autonomy with clean, resumable state.

## Our approach

**Derive state from artifacts instead of recording it.** The plan declares, per stage,
the artifact it produces, the gate that proves it, and the executor that does it; an
item's position is computed — the first stage whose gate doesn't pass — and every
gate-pass is a git commit, so the run history is the git log. The agent maintains no
parallel bookkeeping, which is why the state cannot drift and the audit trail cannot
be fabricated — the two failure modes real runs of an earlier recorded-state design
(a progress ledger the agent updated by hand) exhibited, and the reason this kernel
derives instead of records. The loop stays a protocol the agent reads (docs, not an
engine); one optional small reconciler CLI mechanizes it. Solve this end-to-end for
Claude Code first; cross-agent portability is a later bet.

## Who it's for

**Primary:** The migration owner — an engineer responsible for a large,
mechanical-but-judgment-heavy migration (first instance: Selenium→Playwright, ~2,000
tests). They're hiring Relay to compose a pipeline, supervise the first few picks
until they trust it, then walk away and let it run autonomously for a day or two —
turning a week of babysitting an agent into an afternoon of setup plus spot-checks.

## Key metrics

All read from the repo itself — the pass-commits (`git log --grep='^loop('`) and the
exceptions file (`loop.notes.jsonl`); there is no separate journal to trust:

- **Autonomous-run ratio** — pass-commits ÷ (pass-commits + `attempt`/`park` notes plus
  `approve` notes while un-graduated). Should climb as approvals graduate.
- **Human-touch count** — `approve` + `unpark` notes plus `needs-human` parks; the
  number tuned toward near-zero.
- **Clean-resume rate** — after an interruption, reconcile must reproduce positions
  from commits + notes with no lost or redone work; a divergence is a defect in the
  gate-commit discipline, and it is *detectable* (`reconciler/loop status`), not silent.
- **Orchestrator context flatness** — per-pick context size stays ~constant across
  hundreds of picks. Source: run-time instrumentation.
- **Migration yield** — items whose terminal gate passes without human rework ÷
  attempted; the lagging quality check.

## Tracks

### Derived-state kernel — **built**

The artifact-graph kernel: produces/gate/executor per stage, computed positions, the
gate-commit invariant, staleness-routed reopens, the failure taxonomy. `LOOP.md`.

_Why it serves the approach:_ it *is* the approach — state lives in the artifacts and
the git log, so a day-long job resumes from a reconcile and the orchestrator carries
nothing.

### Confidence-gated human review — **built, unproven at scale**

`approval` stages with `graduation.afterCleanPasses`: heavy human review while trust
is being established, retired automatically once it is earned.

_Why it serves the approach:_ it's how the loop earns the right to run unattended; the
touch-count metric falls as gates graduate.

### Reconciler CLI — **built (v0)**

`reconciler/loop`: status (derive + lint), next, gate (run + commit proof), note, run
(fresh-session pump with stall/parked halts).

_Why it serves the approach:_ it makes the compliant path the cheapest path — the agent
runs one command to gate-and-commit instead of hand-writing bookkeeping.

### Parallel throughput — **kernel-native, unproven at scale**

`policy.parallel` and `batchable` stages; disjoint items need no coordination because
there is no shared state file. The open edge is shared-artifact contention (e.g.
common page objects), currently a serialize-by-convention rule (`LOOP.md` §4).

_Why it serves the approach:_ the ~2,000-test target is unreachable one-item-at-a-time;
parallelism is load-bearing for the strategy, not an optimization.

## Not working on

- **Cross-agent portability (Codex, OpenCode).** Real goal, later bet — Claude Code is
  the first and only target for now. The kernel asks little of the agent (read one
  file, run commands, commit), which should transfer well — a hypothesis until run.
- **Shared-artifact concurrent writes.** Parallelism over disjoint items is native;
  contended shared artifacts stay serialized by convention until a real ownership or
  lock discipline earns its place.
- **A mandatory runtime engine.** The product stays docs-and-protocol; the reconciler
  is optional and adds no rules.
