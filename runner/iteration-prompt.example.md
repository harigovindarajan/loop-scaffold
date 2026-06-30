# Run one loop iteration — {{LOOP_DIR}}

> **This is a starter template — copy it and fill in the `USER:` section below for your
> work type before pointing `runner.json` at it.** The kernel deliberately leaves
> stage-execution detail open ([`LOOP.md` §8](../LOOP.md)); this template supplies the
> fixed fresh-session contract and asks you to supply the rest. Copy to e.g.
> `iteration-prompt.md`, edit, and set `.promptTemplate` in your `runner.json`.

You are running **exactly one** iteration of the loop at `{{LOOP_DIR}}`, in a fresh
session. Nothing carries over from any previous iteration except the files on disk.

Follow the kernel — do not invent or restate loop rules:

- Read `loop-scaffold/LOOP.md` (§4 failure taxonomy, §5 core invariant, §6 operating the
  loop) and `loop-scaffold/prompts/run-one-iteration.md`, and execute them exactly.
- The loop's two state files are `{{LOOP_DIR}}/loop.json` (scaffold) and
  `{{LOOP_DIR}}/loop.state.jsonl` (ledger). Nothing outside these two files carries loop
  state — reconstruct everything you need from them plus the stage's `instructions` docs.

Then do the single iteration, per `prompts/run-one-iteration.md`:

- **Pick** the first actionable row (`status` `pending` or `in-progress`); skip the rest.
  If none, the loop is idle — stop without writing.
- **Run** that row's current stage by `kind` (`agent` / `checkpoint` / `verify`), using the
  stage's `instructions` and the work-specific guidance you fill in below.
- **Checkpoint rejection:** if a `checkpoint` rejects with a `retryable-defect`, do NOT
  persist a same-stage retry here — use `loop-scaffold/prompts/reopen-item.md` to route the
  item back to the producing stage with the reviewer feedback attached.
- **Persist exactly one rewritten ledger line** for the row you advanced — the whole line,
  per [`LOOP.md` §3](../LOOP.md) shape and §6 persist rules.

<!-- ─────────────────────────────────────────────────────────────────────────────────
USER: fill in for your work type. The kernel does not prescribe these — you do.

  • For each `agent` / `checkpoint` stage: which subagent or procedure runs it, and which
    upstream artifacts it consumes (e.g. from the row's `artifacts[]`).
  • For the `verify` stage: the exact command or runbook that decides pass/fail
    (e.g. a test command, a script, a checklist doc under {{LOOP_DIR}}).
  • Any durable handoff artifacts this loop writes and where they live.

Keep it to stage-execution detail only — do not restate the kernel's iteration rules.
───────────────────────────────────────────────────────────────────────────────────── -->

Then **stop**. Do not start a second iteration — the driver decides whether to continue,
and starting another iteration here would break the fresh-context-per-iteration guarantee.
