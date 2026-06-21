---
title: "INTERVIEW.md assumes compose-for-user; real users arrive author-first"
date: 2026-06-22
category: developer-experience
module: loop-protocol
problem_type: developer_experience
component: development_workflow
severity: medium
applies_when:
  - "Authoring or revising INTERVIEW.md or any agent-run loop-setup interview"
  - "A user arrives with a pipeline already in mind rather than wanting one composed for them"
  - "Designing setup questions for users who think in artifacts, feedback loops, and rule sources"
tags: [interview, loop-setup, pipeline-authoring, checkpoint-lifecycle, user-vocabulary, developer-experience]
---

# INTERVIEW.md assumes compose-for-user; real users arrive author-first

## Context

`INTERVIEW.md` defines how an agent turns a task into a runnable loop: ask six
fixed questions "one at a time," map the answers through the composition recipe,
and emit a `loop.json` the user can then "adjust before the first iteration." The
implicit model is **compose-for-user**: the agent owns pipeline construction, and
the user reacts to a proposed default.

A real setup session — migrating a 26-test Selenium/Java suite to Playwright
TypeScript — exercised the interview against an actual user and the framing
fought the user three separate times. The friction is the learning; the specific
pipeline they chose is not. The corrective messages, verbatim:

1. **Opening:** "what do you need from me to setup the loop" — the user wanted an
   upfront checklist of inputs, not a serial quiz.
2. **After being shown a composed default pipeline:** "I need the pipeline to be
   defined by me" — the user wanted to author the stages, not tweak a proposal.
3. **Mid-definition, unprompted:** "this human review would be removed once enough
   contracts have been reviewed and got confidence" — the user expected a
   checkpoint that *graduates away*, a lifecycle the interview never asks about.

The user also expressed their pipeline in their own vocabulary — "convert to a
contract-spec artifact → human review → migrate → 2 feedback loops: static check
against rules/templates + lint, then a live run" — not in the interview's Q3/Q4/Q5
terms ("execution phases", "approval points", "verification").

## Guidance

Treat the six questions as one supported path, not the only one. Four concrete
UX changes to `INTERVIEW.md`:

1. **Add an early compose-mode fork.** Before Q1, ask: *"Do you want to define the
   pipeline stages yourself, or have me propose one from a few questions?"*
   Author-first users skip straight to handing you a stage list (which you still
   validate against `LOOP.md` §2); compose-with users get the existing six
   questions. The current doc only supports compose-with and bolts on "adjust it
   afterward," which is the wrong default for users who already hold a design.

2. **Offer the interview as a checklist, not only a serial quiz.** "Ask one at a
   time" is the prescribed cadence, but real users open with "what do you need from
   me?" Present the full input set at once with recommended defaults and let them
   fill only what they care about. Serial questioning is a fallback for users who
   want to be walked through, not the mandatory shape.

3. **Listen in the user's vocabulary and map it to the kernel.** Users do not think
   in "phases / approval points / verification." Add an explicit translation layer:
   - "feedback loop" → a `verify` stage (and users routinely want *several* in
     sequence — e.g. static-check then live-run — only the last terminal).
   - "the artifact a stage produces" → the Q6 handoff, but users treat it as a
     first-class, reviewable stage **output** (a produced contract that implies a
     `checkpoint` right after it), not as metadata.
   - "rules / templates the check enforces" → a `verify`-stage **input** the
     interview never asks for. Q5 asks *what counts as verification* but not *what
     the verification checks against*. Add that sub-question.

4. **Ask about checkpoint lifecycle.** Q4 locates approval points but assumes they
   are permanent. Ask whether each is permanent or a **temporary confidence gate**
   that retires after N clean passes, and capture the graduation criterion. The
   loop is re-authored between runs by design (`LOOP.md` §1), so a graduating
   checkpoint is fully expressible — the interview just never surfaces the need.

## Why This Matters

`INTERVIEW.md`'s value is converting a human's intent into a correct loop with
minimal friction. When the interview can only hear its own six-question framing, a
user who arrives with a pipeline, their own words for it, and lifecycle
expectations has to *fight the framing* to be understood — exactly the three
corrective turns above. Each correction is a moment the user did the agent's
adaptation work. The kernel (`LOOP.md`) already supports everything the user
wanted (multiple verify stages, checkpoints, re-authoring between runs); the gap is
purely in the **interview's** ability to elicit it. Fixing the elicitation costs a
fork question, a checklist presentation, a vocabulary map, and one lifecycle
question — and removes the most common source of setup-time back-and-forth.

## When to Apply

- Revising `INTERVIEW.md`, its `prompts/construct-loop.md`, or any agent-run setup
  interview for the scaffold.
- Any time a user opens a setup with "what do you need from me?" or "I'll define
  the stages" — route to the author-first path instead of running the quiz.
- Designing setup flows for tools whose users think in produced artifacts,
  feedback loops, and rule sources rather than abstract phases.

## Examples

**Before (current INTERVIEW.md shape):**

```
Agent: [asks Q1..Q6 one at a time]
Agent: Here's the composed pipeline: implement → review → verify.
       Adjust it before we start.
User:  I need the pipeline to be defined by me.        # framing rejected
```

**After (author-first fork + vocabulary map + lifecycle question):**

```
Agent: Want to define the stages yourself, or have me propose from a few questions?
User:  I'll define them: contract-spec → human review → migrate →
       static-check (rules + lint) → live-run.
Agent: Mapping to the kernel: contract-spec & migrate are `agent`; human review is
       a `checkpoint`; static-check and live-run are two `verify` stages
       (live-run terminal). What does static-check check against?   # rule source
User:  Playwright locator/best-practice rules + eslint.
Agent: Is the human review permanent, or a gate that retires once you trust the
       contracts?                                                   # lifecycle
User:  Remove it after ~2 clean batches.
```

The "after" flow elicits in one pass what the "before" flow took three corrective
user messages to surface.

## Related

- `../architecture-patterns/kernel-retry-vs-reopen-boundary.md` — sibling learning
  on what belongs in the kernel vs. canon; same "minimal core, richer behavior at a
  higher layer" instinct, applied here to the interview rather than the taxonomy.
- `INTERVIEW.md` §1 (the six questions), §2 (composition recipe), §3 (output
  contract) — the elicitation surface this learning targets.
- `LOOP.md` §1 (scaffold re-authored between runs) — why a graduating checkpoint is
  already expressible.
