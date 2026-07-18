---
title: "Real users arrive author-first — the session that shaped CONSTRUCT.md"
date: 2026-06-22
category: developer-experience
module: loop-protocol
problem_type: developer_experience
component: development_workflow
severity: medium
applies_when:
  - "Revising CONSTRUCT.md or any agent-run setup/elicitation flow"
  - "A user arrives with a pipeline already in mind rather than wanting one composed"
  - "Designing setup questions for users who think in artifacts, feedback loops, and rule sources"
tags: [construction, loop-setup, pipeline-authoring, graduation, user-vocabulary, developer-experience]
---

# Real users arrive author-first — the session that shaped CONSTRUCT.md

## Context

The loop's original setup flow was a fixed six-question interview, asked one at a
time, after which the agent composed a pipeline for the user to adjust. The implicit
model was **compose-for-user**: the agent owns pipeline construction; the user reacts.

A real setup session — migrating a 26-test Selenium/Java suite to Playwright
TypeScript — ran that interview against an actual user, and the framing fought the
user three separate times. The corrective messages, verbatim:

1. **Opening:** "what do you need from me to setup the loop" — the user wanted an
   upfront checklist of inputs, not a serial quiz.
2. **After being shown a composed default pipeline:** "I need the pipeline to be
   defined by me" — the user wanted to author the stages, not tweak a proposal.
3. **Mid-definition, unprompted:** "this human review would be removed once enough
   contracts have been reviewed and got confidence" — the user expected a review
   gate that *graduates away*, a lifecycle the interview never asked about.

The user also expressed the pipeline in their own vocabulary — "convert to a
contract-spec artifact → human review → migrate → 2 feedback loops: static check
against rules/templates + lint, then a live run" — not in the interview's terms
("execution phases", "approval points", "verification").

## What it taught, and where each fix now lives

Every correction became structure in [`CONSTRUCT.md`](../../../CONSTRUCT.md):

| Finding | Where it landed |
| --- | --- |
| Fork on mode before asking anything — author-first users hand you their stage list; compose-for-me users get guided | `CONSTRUCT.md` §1, the two arrival modes |
| Present the inputs as a checklist with defaults, serial questioning only on request | `CONSTRUCT.md` §1, the checklist |
| Listen in the user's vocabulary and confirm the translation to plan fields | `CONSTRUCT.md` §2, the vocabulary map |
| Ask whether each human review is permanent or retires after N clean passes | the graduation checklist row; mechanics in [`LOOP.md` §6](../../../LOOP.md#6-human-gates-and-graduation) |

## Guidance

For any agent-run setup flow — this repo's or your own:

- **Fork on arrival mode first.** A user who already holds a design should never be
  walked through questions they've answered; validate their stage list instead.
- **Checklist over quiz.** "What do you need from me?" is the most common opening;
  answer it with the full input set and defaults, not the first of six questions.
- **Translate, then confirm.** Users say "feedback loop", "the contract it produces",
  "the rules it's checked against" — map each to a plan field and say the mapping out
  loud so mistranslation surfaces at setup, not mid-run.
- **Ask about gate lifecycle.** Human review gates are usually *temporary confidence
  gates*, not permanent fixtures; elicit the graduation criterion up front.

## Why This Matters

The elicitation surface is where a human's intent becomes a correct loop. The kernel
already supported everything this user wanted — multiple verify stages, approval
gates, plan revisions — the gap was purely the interview's ability to hear it. Each
corrective turn is a moment the user did the agent's adaptation work; the fix cost a
mode fork, a checklist, a vocabulary map, and one lifecycle question.

## When to Apply

- Revising `CONSTRUCT.md` or designing any setup flow whose users think in produced
  artifacts, feedback loops, and rule sources rather than abstract phases.
- Any time a user opens a setup with "what do you need from me?" or "I'll define the
  stages" — route to the author-first path instead of running a quiz.

## Related

- [`CONSTRUCT.md`](../../../CONSTRUCT.md) — the construction canon this session shaped.
- [`LOOP.md` §6](../../../LOOP.md#6-human-gates-and-graduation) — graduation, the
  kernel mechanism behind the "review that retires" expectation.
