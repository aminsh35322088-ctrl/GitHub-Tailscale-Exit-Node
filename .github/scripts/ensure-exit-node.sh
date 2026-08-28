#!/usr/bin/env bash
#
# ensure-exit-node.sh
#
# Guarantees that exactly one Tailscale Exit Node workflow run is either
# active (in_progress) or already waiting in the concurrency queue.
#
# The script is intentionally idempotent so it can be called from several
# places without ever creating a second exit node:
#
#   1. From inside the Exit Node run itself, shortly before it ends, so the
#      successor is already sitting in the concurrency queue and starts as
#      soon as the group is released ("pre-queue").
#   2. From the relaunch job of the Exit Node workflow, as a fallback when the
#      pre-queue step never ran (timeout, failure, cancellation).
#   3. From the watchdog workflow, triggered by workflow_run:completed and by
#      cron as a last-resort backstop.
#
# Required environment:
#   GH_TOKEN   Token with actions:write on REPO
#   REPO       owner/name
#
# Optional environment:
#   WORKFLOW                 Workflow file name       (default tailscale-exit-node.yml)
#   REF                      Git ref to dispatch      (default main)
#   SELF_RUN_ID              Run id to exclude; when set, pending-run cleanup
#                            is skipped because the caller is itself a run of
#                            WORKFLOW and therefore still holds the group.
#   QUEUED_TIMEOUT_MINUTES   Cancel a pending run stuck this long  (default 15)
#   STALE_AGE_MINUTES        Age above which an active run is treated as stuck.
#                            Must exceed the longest legitimate duration of the
#                            whole run: the exit node job's timeout-minutes plus
#                            the relaunch job, otherwise a healthy run can be
#                            cancelled. (default 375)
#   STALE_UPDATE_MINUTES     Additional requirement: no progress reported for
#                            this long. GitHub does not reliably advance
#                            updated_at during a single long-running step, so
#                            treat this as a secondary signal and rely on
#                            STALE_AGE_MINUTES for correctness. (default 20)
#   MIN_HEALTHY_MINUTES      A run shorter than this counts as a short failure (default 15)
#   MAX_SHORT_FAILURES       Consecutive short failures that stop dispatching (default 3)
#   DISABLED                 Kill switch. When "true"/"1"/"yes", never dispatch.
#                            Set the repository variable EXIT_NODE_DISABLED to
#                            break the self-relaunch chain without editing files.
#   DRY_RUN                  When "true", never POST anything      (default false)

set -Eeuo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"

WORKFLOW="${WORKFLOW:-tailscale-exit-node.yml}"
REF="${REF:-main}"
SELF_RUN_ID="${SELF_RUN_ID:-}"
QUEUED_TIMEOUT_MINUTES="${QUEUED_TIMEOUT_MINUTES:-15}"
STALE_AGE_MINUTES="${STALE_AGE_MINUTES:-375}"
STALE_UPDATE_MINUTES="${STALE_UPDATE_MINUTES:-20}"
MIN_HEALTHY_MINUTES="${MIN_HEALTHY_MINUTES:-15}"
MAX_SHORT_FAILURES="${MAX_SHORT_FAILURES:-3}"
DISABLED="${DISABLED:-false}"
DRY_RUN="${DRY_RUN:-false}"

RUNS_API="https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/runs"
RUN_API="https://api.github.com/repos/${REPO}/actions/runs"
DISPATCH_API="https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/dispatches"

AUTH=(
  -H "Accept: application/vnd.github+json"
  -H "Authorization: Bearer ${GH_TOKEN}"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

log()  { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
warn() { printf '::warning::%s\n' "$*"; }

# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

# Fetch recent runs of WORKFLOW. Retries transient API failures.
get_runs() {
  local json attempt
  for attempt in 1 2 3 4 5; do
    json="$(curl -fsSL "${AUTH[@]}" "${RUNS_API}?per_page=30" 2>/dev/null || true)"
    if [ -n "$json" ] && jq -e '.workflow_runs' >/dev/null 2>&1 <<<"$json"; then
      printf '%s' "$json"
      return 0
    fi
    log "GitHub API unreachable, retry ${attempt}/5..."
    sleep $((attempt * 3))
  done
  return 1
}

# POST a cancellation. Treats "already settled" responses as success.
cancel_run() {
  local run_id="$1" code
  if [ "$DRY_RUN" = "true" ]; then
    log "DRY_RUN: would cancel run ${run_id}"
    return 0
  fi
  code="$(curl -sS -o /tmp/ensure-cancel.json -w '%{http_code}' \
    -X POST "${AUTH[@]}" "${RUN_API}/${run_id}/cancel" || true)"
  case "$code" in
    202|409|404) log "Cancel of run ${run_id} accepted or already settled (HTTP ${code})." ;;
    *)
      warn "Failed to cancel run ${run_id} (HTTP ${code})."
      cat /tmp/ensure-cancel.json 2>/dev/null || true
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# jq views over the run list, always excluding SELF_RUN_ID
# ---------------------------------------------------------------------------

others() {
  jq --arg self "$SELF_RUN_ID" \
    '[.workflow_runs[] | select((.id | tostring) != $self)]' <<<"$1"
}

# Runs GitHub is currently executing.
active_runs()  { jq '[.[] | select(.status == "in_progress")] | sort_by(.created_at) | reverse' <<<"$1"; }

# Runs accepted but not yet executing: queued behind the concurrency group.
pending_runs() { jq '[.[] | select(.status != "in_progress" and .status != "completed")] | sort_by(.created_at) | reverse' <<<"$1"; }

minutes_since() {
  local iso="$1" ts now
  ts="$(date -d "$iso" +%s 2>/dev/null || echo 0)"
  [ "$ts" -gt 0 ] || { echo 0; return; }
  now="$(date +%s)"
  echo $(( (now - ts) / 60 ))
}

# ---------------------------------------------------------------------------
# Anti-loop guard
# ---------------------------------------------------------------------------
#
# A crash-looping exit node would otherwise be re-dispatched forever, burning
# Actions minutes at full speed. Runs cancelled by the concurrency group are
# ignored here: they are a normal consequence of replacing a pending run and
# say nothing about the health of the node.

short_failure_streak() {
  local others_json="$1"
  jq -r \
    --argjson limit "$MAX_SHORT_FAILURES" \
    --argjson min_healthy "$MIN_HEALTHY_MINUTES" '
      [ .[]
        | select(.status == "completed")
        | select(.conclusion == "success" or .conclusion == "failure"
                 or .conclusion == "startup_failure" or .conclusion == "timed_out")
      ]
      | sort_by(.created_at) | reverse
      | .[0:$limit] as $recent
      | if ($recent | length) < $limit then
          0
        else
          [ $recent[]
            | ((((.updated_at | fromdateiso8601)
                 - ((.run_started_at // .created_at) | fromdateiso8601)) / 60) as $dur
               | select(.conclusion != "success" and $dur < $min_healthy))
          ] | length
        end
    ' <<<"$others_json"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

dispatch_run() {
  local code
  if [ "$DRY_RUN" = "true" ]; then
    log "DRY_RUN: would dispatch ${WORKFLOW} on ${REF}"
    return 0
  fi
  code="$(curl -sS -o /tmp/ensure-dispatch.json -w '%{http_code}' \
    -X POST "${AUTH[@]}" \
    -H 'Content-Type: application/json' \
    "$DISPATCH_API" \
    -d "$(jq -nc --arg ref "$REF" '{ref: $ref}')" || true)"

  case "$code" in
    204|200)
      log "Dispatch accepted (HTTP ${code})."
      ;;
    *)
      warn "Failed to dispatch ${WORKFLOW} (HTTP ${code})."
      cat /tmp/ensure-dispatch.json 2>/dev/null || true
      return 1
      ;;
  esac
}

# Confirm GitHub really created the run. A 204 only means the request was
# accepted, not that a run exists.
confirm_dispatch() {
  local attempt runs others_json count
  [ "$DRY_RUN" = "true" ] && return 0
  for attempt in 1 2 3 4 5 6; do
    sleep 5
    runs="$(get_runs)" || continue
    others_json="$(others "$runs")"
    count="$(jq '[.[] | select(.status != "completed")] | length' <<<"$others_json")"
    if [ "$count" -gt 0 ]; then
      log "Successor run is present:"
      jq -r '.[] | select(.status != "completed") | "  run \(.id) status=\(.status)"' <<<"$others_json"
      return 0
    fi
    log "Waiting for dispatched run to appear... ${attempt}/6"
  done
  warn "Dispatch was accepted but no run became visible within 30s. A later backstop will retry."
  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "Repository : ${REPO}"
  log "Workflow   : ${WORKFLOW}"
  [ -n "$SELF_RUN_ID" ] && log "Excluding  : run ${SELF_RUN_ID} (caller)"

  case "${DISABLED,,}" in
    true|1|yes)
      log "EXIT_NODE_DISABLED is set. Not dispatching; the relaunch chain stops here."
      return 0
      ;;
  esac

  local runs others_json active pending active_count pending_count
  runs="$(get_runs)" || {
    warn "GitHub API is unreachable. Doing nothing; a later backstop will retry."
    return 0
  }

  others_json="$(others "$runs")"
  active="$(active_runs "$others_json")"
  pending="$(pending_runs "$others_json")"
  active_count="$(jq 'length' <<<"$active")"
  pending_count="$(jq 'length' <<<"$pending")"

  log "Active runs  : ${active_count}"
  log "Pending runs : ${pending_count}"

  # --- An exit node is already running -------------------------------------
  if [ "$active_count" -gt 0 ]; then
    local id created updated age silence
    id="$(jq -r '.[0].id' <<<"$active")"
    created="$(jq -r '.[0].run_started_at // .[0].created_at' <<<"$active")"
    updated="$(jq -r '.[0].updated_at' <<<"$active")"
    age="$(minutes_since "$created")"
    silence="$(minutes_since "$updated")"
    log "Run ${id}: age=${age}m, last update ${silence}m ago"

    # A long lifetime alone is not a fault. Only a run that is both overdue
    # and silent is treated as stuck.
    if [ "$age" -ge "$STALE_AGE_MINUTES" ] && [ "$silence" -ge "$STALE_UPDATE_MINUTES" ]; then
      warn "Run ${id} is stuck (age ${age}m, silent ${silence}m). Cancelling it."
      cancel_run "$id" || return 1

      # The concurrency group is not released until the run leaves
      # in_progress, so a replacement must not be dispatched before then.
      local attempt still
      for attempt in $(seq 1 12); do
        sleep 5
        runs="$(get_runs)" || continue
        still="$(jq --argjson id "$id" \
          '[.workflow_runs[] | select(.id == $id and .status == "in_progress")] | length' <<<"$runs")"
        if [ "$still" -eq 0 ]; then
          log "Run ${id} has left in_progress."
          dispatch_run || return 1
          confirm_dispatch
          return 0
        fi
        log "Waiting for cancellation to settle... ${attempt}/12"
      done
      warn "Run ${id} is still active after 60s. Not dispatching, to avoid two exit nodes."
      return 0
    fi

    log "Exit node is healthy. Nothing to do."
    return 0
  fi

  # --- A successor is already queued ---------------------------------------
  if [ "$pending_count" -gt 0 ]; then
    local pid page pstatus
    pid="$(jq -r '.[0].id' <<<"$pending")"
    pstatus="$(jq -r '.[0].status' <<<"$pending")"
    page="$(minutes_since "$(jq -r '.[0].created_at' <<<"$pending")")"
    log "Run ${pid} is waiting (status=${pstatus}, age=${page}m)."

    # Only the watchdog cleans up pending runs. When SELF_RUN_ID is set the
    # caller is itself a run of WORKFLOW and still holds the concurrency
    # group, so a waiting successor is expected rather than stuck.
    if [ -z "$SELF_RUN_ID" ] && [ "$page" -ge "$QUEUED_TIMEOUT_MINUTES" ]; then
      warn "Run ${pid} has been waiting ${page}m with nothing running. Cancelling and replacing it."
      cancel_run "$pid" || return 1
      sleep 5
      dispatch_run || return 1
      confirm_dispatch
      return 0
    fi

    log "Successor already queued. Nothing to do."
    return 0
  fi

  # --- Nothing running, nothing queued -------------------------------------
  local streak
  streak="$(short_failure_streak "$others_json")"
  if [ "$streak" -ge "$MAX_SHORT_FAILURES" ]; then
    warn "The last ${MAX_SHORT_FAILURES} exit node runs all failed in under ${MIN_HEALTHY_MINUTES}m."
    warn "Refusing to dispatch to avoid a crash loop. Check the Tailscale OAuth secrets and tag:exit ownership."
    return 0
  fi

  log "No exit node is active or queued. Dispatching a new run."
  dispatch_run || return 1
  confirm_dispatch
}

main "$@"
