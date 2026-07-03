# CONSTRUCT.md — from a task to an accepted plan

How an agent turns a user's task into a committed `loop.json`. The flow is
**elicit → compose → user edits → commit → run**; the plan's commit is the acceptance
([`LOOP.md` §8](LOOP.md#8-operating-the-loop)). This doc defines what to ask and how
answers become a plan; the plan shape itself lives in
[`LOOP.md` §1](LOOP.md#1-the-plan) and is not restated here.

---

## 1. Elicit — checklist first, quiz as fallback

Real users arrive in one of two modes. Ask which, or infer it:

- **Author-first** — they already hold a pipeline in their head. Take their stage list
  in their own words and map it (§2); do not force them through questions they've
  already answered.
- **Compose-for-me** — present the full checklist below at once, with defaults, and let
  them fill only what they care about. Walk it serially only if they ask to be guided.

The checklist (each line names the plan field it becomes):

| Input | Becomes |
| --- | --- |
| What is one unit of work — the smallest thing that moves through the pipeline independently? | one id in `items` |
| What are the steps each unit goes through, and **what does each step produce**? | `stages[]`, each with `produces` |
| Who does each step — you, or a named subagent? | `executor` |
| **What command proves each step is done?** Push for a runnable check; a prose gate is a wish ([`LOOP.md` §3](LOOP.md#3-gates)). | `gate` |
| What rules or runbooks does a step follow? | that stage's `instructions` doc |
| Which artifacts must a human review — and does the review **retire** once trusted, after how many clean passes? | `approval` + `graduation.afterCleanPasses` |
| When a review fails, which earlier step owns the fix? | `onFail` |
| Retry / block / escalate intent, and how many retries before a human sees it? | `policy.maxAttempts` + park classification ([`LOOP.md` §5](LOOP.md#5-failure-taxonomy)) |
| How many units in flight at once; which steps can one call cover for many units? | `policy.parallel`, `batchable` |

If an answer is missing, use the leanest default: one `self` stage with an artifact
gate, a terminal `run` gate, `parallel: 1`, `maxAttempts: 3`, no approvals.

## 2. Map the user's vocabulary

Users do not speak in plan fields. Translate, and confirm the translation:

- *"feedback loop"*, *"a check"* → a stage whose `gate` runs that check; several checks
  in sequence are several stages.
- *"the contract / report X produces"* → that stage's `produces` — and if they want it
  reviewed, an `approval` on that same stage, not a new one.
- *"the rules it's checked against"* → the gate command's rule source, or the stage's
  `instructions` runbook.
- *"human review until I trust it"* → `approval.graduation` — ask for the number.
- *"use agent X for that part"* → `executor`.

## 3. Compose

Emit `loop.json` in the [`LOOP.md` §1](LOOP.md#1-the-plan) shape, plus one runbook per
stage that needs it (`docs/stages/<stage>.md` is the working layout), referenced from
`instructions`. Compose fresh — the [`examples/`](examples/) starters are example
outputs, not shortcuts. Prefer:

- `run` gates over artifact gates wherever a command can decide (typecheck, test run,
  a `jq` assertion on a verdict file the reviewing agent writes).
- A verdict **artifact** for judgment stages (review writes `reports/{item}-review.json`;
  the gate asserts on it) so the judgment is inspectable and gateable.
- `batchable` on stages whose one invocation naturally covers many items (probing,
  contract-writing) — that is where the throughput lives.

## 4. Acceptance is the commit

Present the drafted plan. The user edits the file itself — stages, gates, budgets — not
a summary of it. **Execute nothing until the user accepts and `loop.json` is
committed**; git records who accepted and when, so no other acceptance record exists or
is needed. If the plan changes later, that is a new committed revision
([`LOOP.md` §1](LOOP.md#1-the-plan)).

Then run it: [`reconciler/loop run`](reconciler/) unattended, or one pick at a time via
[`prompts/run-one-pick.md`](prompts/run-one-pick.md).
