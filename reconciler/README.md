# reconciler/ — the optional loop CLI

One small tool that mechanizes the v2 kernel's operating steps ([`LOOP.md` §8](../LOOP.md#8-operating-the-loop)).
It adds **no rules** — every behavior below is defined in the kernel; the tool exists so
the compliant path is also the cheapest path. A loop run without it is equally
conformant.

Dependencies: `bash`, `git`, `jq`, `shasum`/`sha256sum`.

## Subcommands

| Command | Kernel step | What it does |
| --- | --- | --- |
| `loop status [--json]` | reconcile ([§2](../LOOP.md#2-position-is-computed-never-stored)) | Validates `loop.json`, derives every item's position from pass-commits + hashes + notes. Substates: `pending`, `ungated` (artifacts with no pass-commit), `stale`, `edited-after-pass`, `awaiting-approval`. This is also the linter. |
| `loop next [--json]` | pick ([§8](../LOOP.md#8-operating-the-loop)) | Prints up to `policy.parallel` picks, splitting `batchable` same-stage items into chunks of ≤ `batchable.max` (bare `true` = one chunk). Picks carry the stage's `with` map and effective timeout. Skips parked, cancelled, and `awaiting-approval` items. |
| `loop gate <item> <stage> [--took MIN]` | gate + persist ([§3–4](../LOOP.md#3-gates)) | Runs the stage's gate; on pass commits the produced artifacts with the `Gate:`/`Inputs:`/`Produces:` trailers (empty commit for gate-only stages), plus `Took:` when `--took` is given. On fail, prints the gate output and the note commands to classify it. |
| `loop note <op> <item>` | persist exceptions ([§5, §7](../LOOP.md#5-failure-taxonomy)) | Appends one well-formed line to `loop.notes.jsonl`. `attempt` auto-computes `n`, takes `--took MIN` (`took_min`), and auto-parks as `needs-human` at `policy.maxAttempts`; `approve` takes `--no-new-findings` (`newFindings: false`, [§6](../LOOP.md#6-human-gates-and-graduation)); `park` requires `--state blocked\|needs-human`. |
| `loop validate` | construction gate ([§8](../LOOP.md#8-operating-the-loop)) | Plan checks only (version, unique ids/stages, gate shape, `with`/`batchable`/timeout/`resetOn` shapes, `onFail` targets). |
| `loop run [--max-iters N]` | the pump | Fresh agent session per pick via `reconciler.json`, bounded by the stage's effective timeout when set. After every session it banks partial work (gates each unadvanced item; a pass commits) and machine-writes the `attempt` note for any non-pass the session left unnoted ([§4, §7](../LOOP.md#4-the-gate–commit-invariant)). Halts on parked items (configurable), on two no-progress sessions, or at `maxIters`; exits 0 when idle. |

All subcommands take `--loop-dir DIR` (default `.`, the directory holding `loop.json`;
artifact paths resolve relative to it).

## `reconciler.json` (for `loop run` only)

Copy [`reconciler.example.json`](reconciler.example.json) into the loop dir. `command`
is the agent invocation with `{PROMPT_FILE}` substituted per session; the generated
prompt names the pick, the kernel, and the exact `gate`/`note` commands to finish with.
Session output is appended to `loop.run.log` (a runtime artifact, not source).

## Known v0 limits

- A stage's hashed inputs are the *per-item* artifacts of earlier stages; shared
  artifacts a stage also edits (e.g. a shared helper module) ride along in `produces` and
  are committed with whichever item gates first — serialize such stages per
  [`LOOP.md` §4](../LOOP.md#4-the-gate–commit-invariant).
- Graduation counts approve/attempt notes in file order across all items of a stage.
- Paths with whitespace are unsupported (item ids are validated to a safe charset).
- The `run` timeout kills the spawned command's shell (then `kill -9`); a grandchild
  process that detaches from it may survive — best-effort, not a supervisor.
