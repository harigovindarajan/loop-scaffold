---
name: Relay
last_updated: 2026-06-23
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

Make the durable ledger the single source of loop state: the agent holds almost nothing
in context — every transition is persisted as one ledger line — so the orchestrator
stays flat over a day-long job and any interruption resumes straight from the ledger.
The loop is a protocol the agent reads (docs, not an engine to install). Solve this
end-to-end for Claude Code first; cross-agent portability is a later bet, not a v1 gate.

## Who it's for

**Primary:** The migration owner — an engineer responsible for a large,
mechanical-but-judgment-heavy migration (first instance: Selenium→Playwright, ~2,000
tests). They're hiring Relay to compose a pipeline, supervise the first few iterations
until they trust it, then walk away and let it run autonomously for a day or two —
turning a week of babysitting an agent into an afternoon of setup plus spot-checks.

## Key metrics

- **Autonomous-run ratio** - iterations completed with zero human touch ÷ total
  iterations; should climb as confidence is tuned out. Source: the append-only run
  journal ([`JOURNAL.md`](JOURNAL.md)), not the live `loop.state.jsonl`, which is a
  mutable table holding current state only.
- **Human-review touch count** - absolute number of human interventions (review1 +
  checkpoint rejections + `needs-human`); the number tuned toward near-zero. Source:
  the run journal ([`JOURNAL.md`](JOURNAL.md)); the live ledger does not retain past
  transitions, so per-item counters like `attempts`/`reopenCount` reflect only the
  current stage.
- **Clean-resume rate** - interruptions that resume correctly with no lost or redone
  work ÷ total interruptions; the direct test of the core bet. Source: replay of the run
  journal ([`JOURNAL.md`](JOURNAL.md)) against the ledger position.
- **Orchestrator context flatness** - per-iteration context size stays ~constant across
  hundreds of iterations. Source: run-time context instrumentation (not in the ledger
  today).
- **Migration yield** - tests passing `review2` (static + runtime) without human rework
  ÷ attempted; the lagging quality check. Source: CI / verify-stage results.

## Tracks

### Resumable ledger kernel

The durable state model — one transition per iteration, resume-from-ledger, the failure
taxonomy. Mostly built today in `LOOP.md`; the foundation everything else stands on.

_Why it serves the approach:_ It *is* "state lives in the ledger, not the context" —
the mechanism that makes a day-long job resumable and immune to context blow-up.

### Confidence-gated human review

Tunable checkpoints, heavy at establishment and ramped out per capability and per batch:
a human reviews the first batch (e.g. 4 mid-to-complex tests) to establish each
capability — contract decisions like test-data isolation, cleanup, and locator strategy,
then runtime verification on that same batch — and once each is trusted the human is
tuned out of it and called only for interruptions.

_Why it serves the approach:_ It's how the loop earns the right to run unattended; it's
the mechanism behind the touch-count and autonomous-run metrics.

### Context durability

Durable memory plus sub-agent delegation so the orchestrator stays flat over a day-long
job instead of accumulating context across hundreds of iterations. Largely unbuilt today
(the kernel is single-agent linear); the design layer this strategy commits to adding.

_Why it serves the approach:_ The autonomy bet fails without it — it's the currently
missing piece the long horizon demands.

### Reference linter

The lightweight checker that validates `loop.json` and `loop.state.jsonl` without executing
stages. Its contract is now ready to build in `LINTER.md`; it is the cheap guardrail for
long unattended runs and the prerequisite for safe batch merge.

_Why it serves the approach:_ It turns ledger-state autonomy from prose discipline into a
repeatable conformance check while keeping the product docs-first rather than engine-first.

### Multi-agent batch execution

Parallel throughput by partitioning established work into independent loop shards, each run
by one worker agent, then merging the resulting ledgers. The first design avoids shared-file
concurrency entirely: no two agents write the same `loop.state.jsonl`.

_Why it serves the approach:_ Once confidence is earned, the same durable state model can
scale from one item at a time to many independent items at once without weakening the kernel.

## Not working on

- **Cross-agent portability (Codex, OpenCode).** Real goal, later bet — Claude Code is
  the first and only target until ledger-state autonomy is proven.
- **Shared-ledger concurrent writes.** Batch execution uses independent shards first; direct
  concurrent edits to one `loop.state.jsonl` wait for a real lock or runtime discipline.
- **A mandatory runtime engine.** The product stays docs-and-protocol, not an installed
  engine.
