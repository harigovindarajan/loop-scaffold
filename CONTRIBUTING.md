# Contributing

**One authoring rule: reference the kernel, never restate it.** [`LOOP.md`](LOOP.md) is
the single source of truth for the plan shape, the position function, the gate–commit
invariant, and the failure taxonomy. Every other doc links to the relevant `LOOP.md`
section instead of re-declaring it — a second normative copy anywhere is a defect even
while the copies agree, because they will drift. The review test: if a reviewer finds
any kernel rule normatively defined in two places, the rule has failed. When unsure
whether something is kernel or canon: if an agent needs it to run a loop cold, it is
kernel and already lives in `LOOP.md`; otherwise it references the kernel.

After solving a non-obvious problem in or around the protocol, capture the learning in
`docs/solutions/<category>/` — the compounding store, and the only part of `docs/` in
version control.
