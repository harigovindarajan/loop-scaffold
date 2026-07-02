# WALKTHROUGH.md

A narrated worked trace of one row moving through the loop. This doc restates no kernel
rules: it shows concrete transitions whose meaning is checked against
[`LOOP.md`](LOOP.md), especially §3, §4, §5, and §6.

The scaffold used here is the shipped checkpoint shape:

```text
implement (agent) -> review (checkpoint) -> verify (verify)
```

`scaffolds/loop.state.example.jsonl` shows rows at rest. This file shows one row moving:
each step has a before line, the action that happened, and the after line that would be
persisted.

---

## 1. Agent stage passes into the checkpoint

Taxonomy code: `pass`. Stage kind: `agent`.

Before:

```jsonl
{"id": "item-001", "status": "pending", "stage": "implement", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": [], "updatedAt": "2026-06-23T10:00:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z"}}
```

Action: `prompts/run-one-iteration.md` runs `implement` and checks the persisted line
against [`LOOP.md` §4](LOOP.md#4-failure-taxonomy) and
[`LOOP.md` §6](LOOP.md#6-operating-the-loop).

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "review", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:05:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z"}}
```

---

## 2. Checkpoint rejection reopens the producer stage

Taxonomy code: `retryable-defect`. Stage kind: `checkpoint`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "review", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:05:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z"}}
```

Action: the checkpoint rejects the artifact. Because repair belongs at the producer,
`prompts/reopen-item.md` performs the write and checks it against its canon reopen behavior
plus [`LOOP.md`](LOOP.md). The reopen write also increments `metadata.reopenCount` (the
bound that escalates a ping-ponging item to `human-exception` past the loop's budget);
it is omitted from the rows below for brevity.

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "implement", "attempts": 0, "lastError": {"code": "retryable-defect", "note": "review rejected: add the missing setup note"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:08:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "add the missing setup note"}}
```

---

## 3. Agent repair passes back to review

Taxonomy code: `pass`. Stage kind: `agent`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "implement", "attempts": 0, "lastError": {"code": "retryable-defect", "note": "review rejected: add the missing setup note"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:08:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "add the missing setup note"}}
```

Action: `prompts/run-one-iteration.md` repairs the artifact and persists the next line
after its self-check.

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "review", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:16:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

---

## 4. Checkpoint passes into verification

Taxonomy code: `pass`. Stage kind: `checkpoint`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "review", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:16:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

Action: `prompts/run-one-iteration.md` runs the checkpoint again and persists the checked
line.

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:20:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

---

## 5. Verification finds a retryable defect in place

Taxonomy code: `retryable-defect`. Stage kind: `verify`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:20:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

Action: `prompts/run-one-iteration.md` runs verification, classifies the failure, and
persists the checked line using the same-stage retry boundary in
[`LOOP.md` §4](LOOP.md#4-failure-taxonomy).

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": {"code": "retryable-defect", "note": "verification failed: note lacks final command output"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:23:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

---

## 6. Verification hits an environmental block

Taxonomy code: `blocked-environment`. Stage kind: `verify`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": {"code": "retryable-defect", "note": "verification failed: note lacks final command output"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:23:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

Action: the verification command cannot run because the required service is unavailable;
`prompts/run-one-iteration.md` classifies and persists the checked line.

After:

```jsonl
{"id": "item-001", "status": "blocked", "stage": "verify", "attempts": 1, "lastError": {"code": "blocked-environment", "note": "verification service unavailable"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:27:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

---

## 7. Environmental block clears and the row is unparked

Taxonomy code: none; this is the administrative unpark path in
[`LOOP.md` §6](LOOP.md#6-operating-the-loop).

Before:

```jsonl
{"id": "item-001", "status": "blocked", "stage": "verify", "attempts": 1, "lastError": {"code": "blocked-environment", "note": "verification service unavailable"}, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:27:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note"}}
```

Action: `prompts/resume-parked-item.md` rewrites the row after confirming the service has
returned and the line remains well-formed against [`LOOP.md` §3](LOOP.md#3-work-item-row-shape).

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:45:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored"}}
```

---

## 8. Verification needs a human decision

Taxonomy code: `human-exception`. Stage kind: `verify`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:45:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored"}}
```

Action: verification reaches a product question only a human can answer;
`prompts/run-one-iteration.md` classifies and persists the checked line.

After:

```jsonl
{"id": "item-001", "status": "needs-human", "stage": "verify", "attempts": 1, "lastError": {"code": "human-exception", "note": "human decision needed: include the flaky-output caveat?"}, "needsHuman": true, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:50:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored"}}
```

---

## 9. Human input arrives and the row is unparked

Taxonomy code: none; this is the second administrative unpark path in
[`LOOP.md` §6](LOOP.md#6-operating-the-loop).

Before:

```jsonl
{"id": "item-001", "status": "needs-human", "stage": "verify", "attempts": 1, "lastError": {"code": "human-exception", "note": "human decision needed: include the flaky-output caveat?"}, "needsHuman": true, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T10:50:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored"}}
```

Action: `prompts/resume-parked-item.md` records the human answer and checks the rewritten
line against [`LOOP.md` §3](LOOP.md#3-work-item-row-shape).

After:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T11:10:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored", "humanInput": "include the caveat in the verification note"}}
```

---

## 10. Terminal verification passes

Taxonomy code: `pass`. Stage kind: `verify`.

Before:

```jsonl
{"id": "item-001", "status": "in-progress", "stage": "verify", "attempts": 1, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T11:10:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored", "humanInput": "include the caveat in the verification note"}}
```

Action: `prompts/run-one-iteration.md` runs the terminal stage, applies the checked
`pass` result against [`LOOP.md` §4](LOOP.md#4-failure-taxonomy) and
[`LOOP.md` §6](LOOP.md#6-operating-the-loop), and persists the final line.

After:

```jsonl
{"id": "item-001", "status": "done", "stage": null, "attempts": 0, "lastError": null, "needsHuman": false, "artifacts": ["docs/validation-note.md"], "updatedAt": "2026-06-23T11:18:00Z", "metadata": {"task": "produce the validation note", "acceptedAt": "2026-06-23T09:55:00Z", "reviewFeedback": "addressed: add the missing setup note", "unblockedBy": "verification service restored", "humanInput": "include the caveat in the verification note"}}
```

---

## Coverage Map

The trace gives a concrete place to inspect each kernel behavior without defining it here:

- Taxonomy codes: `pass` (§1, §3, §4, §10), `retryable-defect` (§2, §5),
  `blocked-environment` (§6), `human-exception` (§8).
- Stage kinds: `agent` (§1, §3), `checkpoint` (§2, §4), `verify` (§5, §6, §8, §10).
- Canon paths: checkpoint reject -> reopen (§2), blocked unpark (§7), needs-human unpark
  (§9).

For the actual rule text behind those examples, read [`LOOP.md`](LOOP.md).
