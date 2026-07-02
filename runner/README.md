# runner — optional fresh-context iteration driver

This directory is **optional**. The loop protocol is still docs, not a runtime — there is
no engine to install ([`../README.md`](../README.md)). Reach for `run-loop.sh` only when
you want to run a constructed loop **unattended in fresh sessions** (claude / opencode),
spawning **one fresh agent session per iteration** instead of advancing every slice inside
one long-lived session.

Each spawned session advances the loop by exactly one transition
([`LOOP.md` §5](../LOOP.md)) and hands off purely through the loop's files —
`loop.json` + `loop.state.jsonl` + any on-disk artifacts. The driver carries no loop state
in memory; it only orchestrates and gates. It adds **no loop rules**
([`AUTHORING.md`](../AUTHORING.md)); the per-iteration logic is
[`prompts/run-one-iteration.md`](../prompts/run-one-iteration.md)
([`LOOP.md` §6](../LOOP.md)).

In the terms of [`LOOP.md` §7](../LOOP.md#7-adapter-stub), `run-loop.sh` plus your
filled-in iteration prompt **is a fresh-session adapter**: it discharges the adapter
stub's six steps by spawning one session per iteration, adding invocation and gating
detail only. A same-session adapter would instead follow those six steps inline in one
long-lived session.

## Vendoring assumption

The driver resolves the repo root as the **parent of `loop-scaffold/`** and runs from
there, so config paths are **project-relative**. This assumes the scaffold is vendored as a
`loop-scaffold/` subdirectory inside your project, with your loop dirs alongside it.

## What's here

| File | What it is |
|------|------------|
| `run-loop.sh` | The external driver. Depends only on `bash` + `jq`. |
| `iteration-prompt.example.md` | Starter prompt template — **copy and fill in for your work type.** |
| `runner.example.json` | Starter per-loop config — copy to `<loop-dir>/runner.json`. |

## Point it at a loop

1. **Have a constructed loop.** `<loop-dir>/loop.json` + a seeded `<loop-dir>/loop.state.jsonl`,
   built via [`prompts/construct-loop.md`](../prompts/construct-loop.md) behind the
   construction-before-execution gate ([`../README.md`](../README.md)). Do not seed a ledger
   straight from a task.
2. **Write your iteration prompt.** Copy `iteration-prompt.example.md` to your own file
   (e.g. `iteration-prompt.md`) and fill in the `USER:` section — which subagent/procedure
   runs each stage, and how the `verify` stage decides pass/fail.
3. **Add a runner config.** Copy `runner.example.json` to `<loop-dir>/runner.json`. Point
   `.promptTemplate` at your prompt from step 2 and pick the runtime in `.command` — both
   forms run **fully autonomous** (no permission prompts) and set the model with `--model`:
   - Claude: `claude -p "$(cat {PROMPT_FILE})" --model sonnet --dangerously-skip-permissions`
   - opencode: `opencode run --model openai/gpt5.4 --dangerously-skip-permissions "$(cat {PROMPT_FILE})"`

   `{PROMPT_FILE}` is substituted with the rendered per-iteration prompt. The defaults are
   `sonnet` (claude) and `openai/gpt5.4` (opencode); change `--model` to pick another.
   `haltOnParked` (default `true`) stops the whole run on any `blocked` / `needs-human`
   row; set it `false` to skip parked rows and keep advancing the actionable ones instead.
   The reopen/retry budget is a **loop** setting, not a runner one — set
   `metadata.maxReopens` in the scaffold ([`prompts/reopen-item.md`](../prompts/reopen-item.md)).
4. **Run it.**

```bash
bash loop-scaffold/runner/run-loop.sh --loop-dir <loop-dir>            # run to completion
bash loop-scaffold/runner/run-loop.sh --loop-dir <loop-dir> --dry-run  # show next step only
bash loop-scaffold/runner/run-loop.sh --loop-dir <loop-dir> --max-iters 1
```

## Flags

| Flag | Meaning |
|------|---------|
| `--loop-dir <path>` | **Required.** Dir holding `loop.json` + `loop.state.jsonl`. |
| `--config <path>` | Runner config. Defaults to `<loop-dir>/runner.json`. |
| `--max-iters N` | Hard cap on iterations (default from config, else 60). |
| `--dry-run` | Pre-flight + print the command and rendered prompt; spawn nothing. |

## Stop semantics

Each iteration: **pre-flight** scans the ledger, **spawns** a fresh session, **post-flight**
re-scans to confirm progress.

| Outcome | Exit | When |
|---------|------|------|
| **Halt** (bad ledger) | 1 | `loop.state.jsonl` does not parse as JSONL. Pre-flight catches it before any query, so a corrupt file can't read as "idle." Fix it and re-run. |
| **Halt** (parked) | 1 | A row is `blocked` or `needs-human` **and** `haltOnParked` is `true` (default). Resolve it ([`prompts/resume-parked-item.md`](../prompts/resume-parked-item.md)) and re-run, or set `haltOnParked: false` to skip parked rows. This is a runner policy — the kernel itself skips parked rows and keeps going ([`LOOP.md` §6](../LOOP.md)). |
| **Idle** | 0 | No `pending`/`in-progress` rows left; the loop is complete. |
| **Halt** (stall) | 1 | A spawned session **exited cleanly** but left the target row unchanged twice in a row (`STALL_LIMIT`); the row is genuinely wedged. Inspect manually. |
| **Halt** (crash) | 1 | A spawned session **exited non-zero** and left the row unchanged three times in a row (`CRASH_LIMIT`); the session keeps crashing before it can persist a transition. Inspect manually. |
| **Cap** | 0 | `--max-iters` reached; resumable — just re-run. |

A crashed session (non-zero exit, no transition) is tracked separately from a clean
no-op so a flaky stage that crashes-then-succeeds is not mistaken for a wedged row:
a crash counts toward `CRASH_LIMIT`, a clean no-op counts toward `STALL_LIMIT`, and any
real transition resets both. Progress is appended to `run-loop.log` (one line per event,
including `CRASH`; gitignored).
