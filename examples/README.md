# examples/ — starter plans

Example **outputs** of the construction flow ([`CONSTRUCT.md`](../CONSTRUCT.md)) — read
them to see the [`LOOP.md` §1](../LOOP.md#1-the-plan) shape in the small, then compose
your own fresh; do not copy one as a shortcut past the elicitation.

| File | Shape |
| --- | --- |
| [`loop.minimal.json`](loop.minimal.json) | The leanest legal loop: one work stage with an artifact gate, one terminal `run` gate. The default when elicitation answers are missing. |
| [`loop.review-gated.json`](loop.review-gated.json) | The working shape from real migrations: a batchable contract stage (≤3 items per call), a delegated implement stage gated by typecheck with a `with` input, an agent review writing a verdict artifact (`gate.expects` names its shape; `onFail` routes fixes back to implement; human approval graduates after 3 clean passes, reclassification-only attempts not resetting the streak), and a terminal test gate. |

Both are runnable as-is in a fresh git repo once committed (`reconciler/loop validate`
checks them), but their gates reference commands (`npm test`, reviewer agents) you will
substitute with your project's own.
