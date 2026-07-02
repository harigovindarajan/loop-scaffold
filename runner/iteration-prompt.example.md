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

Then do the single iteration exactly as
[`prompts/run-one-iteration.md`](../prompts/run-one-iteration.md) specifies — pick one
actionable row, run its stage using the stage's `instructions` and your fill-in below,
classify, and persist exactly one rewritten ledger line. Follow that prompt; do not
restate its rules here. The one reminder worth repeating for a fresh session: on a
`checkpoint` rejection, do **not** persist a same-stage retry — use
[`loop-scaffold/prompts/reopen-item.md`](../prompts/reopen-item.md) to route the item back
to its producing stage with the reviewer feedback attached.

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
