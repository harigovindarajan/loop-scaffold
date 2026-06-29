#!/usr/bin/env bash
#
# run-loop.sh — fresh-context iteration driver for a loop-scaffold loop.
#
# Spawns ONE fresh agent session per iteration, each of which advances the loop by
# exactly one transition (per loop-scaffold/prompts/run-one-iteration.md). All state
# lives in the loop's two files; this driver carries nothing across iterations except
# loop-control counters. It adds NO loop rules — see loop-scaffold/AUTHORING.md.
#
# The driver is the only gate: it halts the whole loop on any blocked / needs-human row,
# stops cleanly when the loop is idle, and caps runaway loops with --max-iters and a
# no-progress stall guard.
#
# Usage:
#   run-loop.sh --loop-dir <path> [--config <path>] [--max-iters N] [--dry-run]
#
set -euo pipefail

# --- resolve repo root (parent of loop-scaffold/) so config-relative paths resolve -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

LOG_FILE="${SCRIPT_DIR}/run-loop.log"
STALL_LIMIT=2

# --- arg parsing -----------------------------------------------------------------------
LOOP_DIR=""
CONFIG=""
MAX_ITERS=""
DRY_RUN=0

die() { echo "run-loop: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop-dir)  LOOP_DIR="${2:?--loop-dir needs a value}"; shift 2 ;;
    --config)    CONFIG="${2:?--config needs a value}"; shift 2 ;;
    --max-iters) MAX_ITERS="${2:?--max-iters needs a value}"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "${LOOP_DIR}" ]] || die "missing required --loop-dir"
[[ -d "${LOOP_DIR}" ]] || die "loop-dir not found: ${LOOP_DIR}"

LEDGER="${LOOP_DIR%/}/loop.state.jsonl"
SCAFFOLD="${LOOP_DIR%/}/loop.json"
[[ -f "${LEDGER}"  ]] || die "no ledger at ${LEDGER}"
[[ -f "${SCAFFOLD}" ]] || die "no scaffold at ${SCAFFOLD}"

CONFIG="${CONFIG:-${LOOP_DIR%/}/runner.json}"
[[ -f "${CONFIG}" ]] || die "no runner config at ${CONFIG} (pass --config)"

command -v jq >/dev/null || die "jq is required"

# --- read config -----------------------------------------------------------------------
CMD_TEMPLATE="$(jq -r '.command'        "${CONFIG}")"
PROMPT_TMPL="$( jq -r '.promptTemplate' "${CONFIG}")"
CFG_MAX="$(     jq -r '.maxIters // 60' "${CONFIG}")"
MAX_ITERS="${MAX_ITERS:-${CFG_MAX}}"

[[ "${CMD_TEMPLATE}" != "null" && -n "${CMD_TEMPLATE}" ]] || die "config .command is empty"
[[ -f "${PROMPT_TMPL}" ]] || die "promptTemplate not found: ${PROMPT_TMPL}"

# scratch dir for rendered per-iteration prompts (fresh file each iteration)
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/run-loop.XXXXXX")"
trap 'rm -rf "${SCRATCH}"' EXIT

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "${LOG_FILE}"; }

# ledger query helpers (read-only; treat the jsonl as a slurped array) -------------------
# first parked row (blocked|needs-human), as "id\tstatus\tlastError" or empty
parked_row() {
  jq -rs '
    first(.[] | select(.status=="blocked" or .status=="needs-human"))
    | select(. != null)
    | [.id, .status, (.lastError|tostring)] | @tsv
  ' "${LEDGER}"
}
# first actionable row (pending|in-progress), as "id\tstatus\tstage\tupdatedAt" or empty
actionable_row() {
  jq -rs '
    first(.[] | select(.status=="pending" or .status=="in-progress"))
    | select(. != null)
    | [.id, .status, (.stage|tostring), (.updatedAt|tostring)] | @tsv
  ' "${LEDGER}"
}
# snapshot of one row's mutable fields, as "status\tstage\tupdatedAt"
row_snapshot() {
  local id="$1"
  jq -rs --arg id "$id" '
    first(.[] | select(.id==$id))
    | [(.status|tostring), (.stage|tostring), (.updatedAt|tostring)] | @tsv
  ' "${LEDGER}"
}

# --- main loop -------------------------------------------------------------------------
log "START loop-dir=${LOOP_DIR} config=${CONFIG} max-iters=${MAX_ITERS} dry-run=${DRY_RUN}"

iter=0
stalls=0

while (( iter < MAX_ITERS )); do

  # ---- pre-flight ----
  parked="$(parked_row || true)"
  if [[ -n "${parked}" ]]; then
    IFS=$'\t' read -r pid pstatus perr <<<"${parked}"
    log "HALT parked row ${pid} status=${pstatus} lastError=${perr}"
    echo "run-loop: halted — resolve ${pid} (${pstatus}), then re-run." >&2
    exit 1
  fi

  next="$(actionable_row || true)"
  if [[ -z "${next}" ]]; then
    log "IDLE no actionable rows — loop complete"
    exit 0
  fi
  IFS=$'\t' read -r tid tstatus tstage tupdated <<<"${next}"

  iter=$(( iter + 1 ))
  log "ITER ${iter}/${MAX_ITERS} target=${tid} status=${tstatus} stage=${tstage}"

  # ---- render fresh prompt ----
  PROMPT_FILE="${SCRATCH}/iter-${iter}.prompt.md"
  sed "s#{{LOOP_DIR}}#${LOOP_DIR%/}#g" "${PROMPT_TMPL}" > "${PROMPT_FILE}"

  # substitute {PROMPT_FILE} into the configured command
  cmd="${CMD_TEMPLATE//\{PROMPT_FILE\}/${PROMPT_FILE}}"

  if (( DRY_RUN )); then
    log "DRY-RUN would spawn: ${cmd}"
    echo "--- rendered prompt (${PROMPT_FILE}) ---"
    cat "${PROMPT_FILE}"
    exit 0
  fi

  # ---- spawn fresh context (this new process IS the fresh session) ----
  if ! bash -c "${cmd}"; then
    log "WARN iteration command exited non-zero (target=${tid}); checking ledger anyway"
  fi

  # ---- post-flight ----
  after="$(row_snapshot "${tid}" || true)"
  IFS=$'\t' read -r astatus astage aupdated <<<"${after}"

  if [[ "${aupdated}" == "${tupdated}" && "${astatus}" == "${tstatus}" && "${astage}" == "${tstage}" ]]; then
    stalls=$(( stalls + 1 ))
    log "STALL ${stalls}/${STALL_LIMIT} no transition on ${tid} (stage=${astage} status=${astatus})"
    if (( stalls >= STALL_LIMIT )); then
      log "HALT no progress after ${STALL_LIMIT} consecutive stalls on ${tid}"
      echo "run-loop: halted — ${tid} is wedged at stage ${astage}; inspect manually." >&2
      exit 1
    fi
  else
    stalls=0
    log "OK ${tid} -> status=${astatus} stage=${astage}"
  fi
done

log "CAP reached --max-iters=${MAX_ITERS}; stopping (loop not necessarily complete)"
exit 0
