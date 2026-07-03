# Portable Agent Loop

The loop protocol for coding agents — as **docs, not a runtime**. Version 2, the
**artifact-graph kernel**: the plan declares, per stage, the artifact it produces, the
gate that proves it, and the executor that does it. An item's position is *derived* —
the first stage whose gate doesn't pass — never written; every gate-pass is a git
commit, so the run history is the git log. There is no state ledger to keep in sync,
nothing to drift, nothing to fake.

## Start here

Read **[`LOOP.md`](LOOP.md)** — the whole kernel, and the single source of truth for
the plan shape, the position function, the gate–commit invariant, and the failure
taxonomy. Reading it plus an accepted `loop.json` is everything an agent needs.

**Building the plan comes first, and it is gated.** Follow
[`CONSTRUCT.md`](CONSTRUCT.md): elicit (checklist, in the user's vocabulary), compose
`loop.json`, let the user edit the file itself, and **execute nothing until the plan is
committed** — the commit is the acceptance.

## Quickstart

```sh
git init                      # the kernel requires a git repo
# 1. build loop.json via CONSTRUCT.md (examples/ shows the shape), edit, commit it
# 2. derive positions, pick, execute, gate, commit — LOOP.md §8
#    …or let the reconciler mechanize it:
reconciler/loop status        # where is every item? (also validates the plan)
reconciler/loop next          # what to do now
reconciler/loop gate tc-01 probe    # run the gate; commit the proof on pass
reconciler/loop run           # fresh agent session per pick, unattended
```

## Worked example — a code migration (Selenium → Playwright)

The task the v2 kernel is benchmarked on. You don't seed a ledger; per
[`CONSTRUCT.md`](CONSTRUCT.md) you describe the pipeline in your own words and let the
agent compose the plan. Prompt to green:

**1. The prompt** — describe the pipeline, in your vocabulary:

> Migrate our Selenium E2E suite to Playwright. **One unit of work is a single spec
> file** — start with `login`, `checkout`, and `search`. Each spec goes through four
> steps:
>
> 1. **probe** — read the Selenium test and write a locator + flow map to
>    `locator-maps/{spec}.json`; done when its `status` is `completed`. **Batch this** —
>    do all three in one pass.
> 2. **port** — hand the map to the **migrator subagent**, which writes the Playwright
>    spec to `tests/{spec}.ts`; done when it typechecks.
> 3. **review** — the **reviewer subagent** writes a PASS/FAIL verdict to
>    `reports/{spec}-review.json`; if it fails, the fix goes back to **port**. I want to
>    eyeball these until I trust it — **retire the human check after 3 clean passes**.
> 4. **test** — done when `npx playwright test` passes; keep no artifact, the run *is*
>    the proof.
>
> Two specs in flight at once, 3 retries before you park it for me. Build `loop.json`,
> show me, and **run nothing until I've committed it**.

**2. The composed `loop.json`** — every phrase above lands on a plan field
([`LOOP.md` §1](LOOP.md#1-the-plan)); nothing invented:

```json
{
  "name": "selenium-to-playwright",
  "version": 2,
  "items": ["login.spec", "checkout.spec", "search.spec"],
  "stages": [
    {
      "name": "probe",
      "executor": "self",
      "produces": ["locator-maps/{item}.json"],
      "gate": { "run": "jq -e '.status==\"completed\"' locator-maps/{item}.json" },
      "instructions": "docs/stages/probe.md",
      "batchable": true
    },
    {
      "name": "port",
      "executor": "migrator-agent",
      "produces": ["tests/{item}.ts"],
      "gate": { "run": "npx tsc --noEmit" },
      "instructions": "docs/stages/port.md"
    },
    {
      "name": "review",
      "executor": "reviewer-agent",
      "produces": ["reports/{item}-review.json"],
      "gate": { "run": "jq -e '.verdict==\"PASS\"' reports/{item}-review.json" },
      "onFail": "port",
      "approval": { "graduation": { "afterCleanPasses": 3 } }
    },
    {
      "name": "test",
      "executor": "self",
      "produces": [],
      "gate": { "run": "npx playwright test tests/{item}.ts" }
    }
  ],
  "policy": { "parallel": 2, "maxAttempts": 3 }
}
```

**3. Commit is the acceptance, then run** — the git log becomes the run history:

```sh
git add loop.json && git commit -m "accept: selenium→playwright plan"
reconciler/loop validate      # ids unique, gates well-formed, onFail targets exist
reconciler/loop run --max-iters 40   # batched probe, port→review per spec, test to green
git log --grep='^loop(' --oneline    # the run history — no journal to keep
```

Same four verbs as any other loop — only the `items`, the `gate` commands, and the two
subagents changed. The protocol is fixed; your task fills in the blanks. Compose fresh:
the [`examples/`](examples/) starters are example outputs, not shortcuts past the
elicitation.

## What's in the repo

| Path | Purpose |
| --- | --- |
| [`LOOP.md`](LOOP.md) | **The v2 kernel.** Read first; everything else references it. |
| [`CONSTRUCT.md`](CONSTRUCT.md) | Task → accepted plan: elicitation checklist, vocabulary map, compose, commit-as-acceptance. |
| [`WALKTHROUGH.md`](WALKTHROUGH.md) | Narrated trace: gates, staleness reopen, approval graduation, parking, resume. |
| [`examples/`](examples/) | Starter plans — example outputs of the construction flow. |
| [`prompts/run-one-pick.md`](prompts/run-one-pick.md) | The one runnable prompt: advance the loop by a single pick. |
| [`reconciler/`](reconciler/) | **Optional** CLI: `status` / `next` / `gate` / `note` / `validate` / `run`. Mechanizes the kernel; adds no rules. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The one authoring rule: reference the kernel, never restate it. |
| [`STRATEGY.md`](STRATEGY.md) | Product strategy, metrics (read from git log + notes), track status. |
| `docs/solutions/` | Compounding-knowledge store (learnings from real runs). |

## Status

v2 (this branch) ships the artifact-graph kernel, the construction canon, the worked
trace, the starter plans, and the reconciler CLI — replacing v1's recorded-state ledger,
journal, interview prompts, shard-based batch canon, and separate linter/runner
contracts. v1 is frozen on the **`v1` branch**; the redesign rationale and evidence live
in `docs/plans/2026-07-03-relay-v2-artifact-graph-redesign.md` (on disk, unversioned).
Merging v2 to `main` is gated on re-running the Selenium→Playwright benchmark against
this kernel.
