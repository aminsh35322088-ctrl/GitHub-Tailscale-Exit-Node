#!/usr/bin/env bash
# Offline tests for ensure-exit-node.sh using a curl/sleep test double.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../ensure-exit-node.sh"
FAKEBIN="$HERE/fakebin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0

now_offset() { date -u -d "@$(( $(date +%s) - $1 * 60 ))" +%Y-%m-%dT%H:%M:%SZ; }

# run <name> <runs-json-file> <expect: dispatch|cancel+dispatch|none> [extra env...]
run_case() {
  local name="$1" runs="$2" expect="$3"; shift 3
  local log="$TMP/post.log"; : > "$log"
  local out
  local -a envs=(
    PATH="$FAKEBIN:$PATH"
    MOCK_RUNS="$runs"
    POST_LOG="$log"
    GH_TOKEN=fake
    REPO=owner/repo
  )
  [ -n "${MOCK_RUNS_AFTER:-}" ] && envs+=("MOCK_RUNS_AFTER=$MOCK_RUNS_AFTER")
  out="$(env "${envs[@]}" "$@" bash "$SCRIPT" 2>&1)"

  local dispatches cancels verdict
  dispatches="$(grep -c '/dispatches$' "$log" || true)"
  cancels="$(grep -c '/cancel$' "$log" || true)"

  case "$expect" in
    dispatch)        [ "$dispatches" -eq 1 ] && [ "$cancels" -eq 0 ] && verdict=ok ;;
    cancel+dispatch) [ "$dispatches" -eq 1 ] && [ "$cancels" -eq 1 ] && verdict=ok ;;
    cancel)          [ "$dispatches" -eq 0 ] && [ "$cancels" -eq 1 ] && verdict=ok ;;
    none)            [ "$dispatches" -eq 0 ] && [ "$cancels" -eq 0 ] && verdict=ok ;;
  esac

  if [ "${verdict:-bad}" = ok ]; then
    PASS=$((PASS + 1))
    printf 'PASS  %-46s (dispatch=%s cancel=%s)\n' "$name" "$dispatches" "$cancels"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %-46s expected %s, got dispatch=%s cancel=%s\n' "$name" "$expect" "$dispatches" "$cancels"
    printf '%s\n' "$out" | sed 's/^/        /'
  fi
  unset MOCK_RUNS_AFTER
}

# --- nothing running, nothing queued -> start one ---------------------------
cat > "$TMP/empty.json" <<'EOF'
{"workflow_runs":[]}
EOF
run_case "idle tailnet starts a node" "$TMP/empty.json" dispatch

# --- healthy active run -> leave it alone -----------------------------------
cat > "$TMP/healthy.json" <<EOF
{"workflow_runs":[{"id":10,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 120)","run_started_at":"$(now_offset 120)","updated_at":"$(now_offset 1)"}]}
EOF
run_case "healthy active run is untouched" "$TMP/healthy.json" none

# --- old but still reporting -> not stale ------------------------------------
cat > "$TMP/old-alive.json" <<EOF
{"workflow_runs":[{"id":11,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 500)","run_started_at":"$(now_offset 500)","updated_at":"$(now_offset 2)"}]}
EOF
run_case "long run that still reports is kept" "$TMP/old-alive.json" none

# --- old and silent -> replace ----------------------------------------------
cat > "$TMP/stuck.json" <<EOF
{"workflow_runs":[{"id":12,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 500)","run_started_at":"$(now_offset 500)","updated_at":"$(now_offset 60)"}]}
EOF
cat > "$TMP/stuck-gone.json" <<EOF
{"workflow_runs":[{"id":12,"status":"completed","conclusion":"cancelled",
  "created_at":"$(now_offset 500)","run_started_at":"$(now_offset 500)","updated_at":"$(now_offset 1)"}]}
EOF
MOCK_RUNS_AFTER="$TMP/stuck-gone.json" \
  run_case "stuck run is cancelled and replaced" "$TMP/stuck.json" cancel+dispatch

# --- cancel accepted but run refuses to die -> do not dispatch ---------------
run_case "no replacement while stuck run lingers" "$TMP/stuck.json" cancel

# --- successor already queued behind an active run --------------------------
cat > "$TMP/queued-behind.json" <<EOF
{"workflow_runs":[
 {"id":20,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 300)","run_started_at":"$(now_offset 300)","updated_at":"$(now_offset 1)"},
 {"id":21,"status":"queued","conclusion":null,
  "created_at":"$(now_offset 1)","run_started_at":null,"updated_at":"$(now_offset 1)"}]}
EOF
run_case "queued successor is not duplicated" "$TMP/queued-behind.json" none

# --- the handover case: caller is the active run, successor waiting ---------
run_case "handover sees its own successor" "$TMP/queued-behind.json" none SELF_RUN_ID=20

# --- handover with no successor yet -> queue one ----------------------------
cat > "$TMP/self-only.json" <<EOF
{"workflow_runs":[{"id":30,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 300)","run_started_at":"$(now_offset 300)","updated_at":"$(now_offset 1)"}]}
EOF
cat > "$TMP/self-plus.json" <<EOF
{"workflow_runs":[
 {"id":30,"status":"in_progress","conclusion":null,
  "created_at":"$(now_offset 300)","run_started_at":"$(now_offset 300)","updated_at":"$(now_offset 1)"},
 {"id":31,"status":"queued","conclusion":null,
  "created_at":"$(now_offset 0)","run_started_at":null,"updated_at":"$(now_offset 0)"}]}
EOF
MOCK_RUNS_AFTER="$TMP/self-plus.json" \
  run_case "handover queues a successor" "$TMP/self-only.json" dispatch SELF_RUN_ID=30

# --- pending run stuck with nothing running -> replace it -------------------
cat > "$TMP/orphan-queued.json" <<EOF
{"workflow_runs":[{"id":40,"status":"queued","conclusion":null,
  "created_at":"$(now_offset 45)","run_started_at":null,"updated_at":"$(now_offset 45)"}]}
EOF
run_case "orphaned queued run is replaced" "$TMP/orphan-queued.json" cancel+dispatch

# --- same, but the caller is a run of the workflow -> leave the queue alone --
run_case "handover never cancels the queue" "$TMP/orphan-queued.json" none SELF_RUN_ID=99

# --- crash loop -> stop dispatching ----------------------------------------
cat > "$TMP/crashloop.json" <<EOF
{"workflow_runs":[
 {"id":50,"status":"completed","conclusion":"failure",
  "created_at":"$(now_offset 30)","run_started_at":"$(now_offset 30)","updated_at":"$(now_offset 28)"},
 {"id":51,"status":"completed","conclusion":"failure",
  "created_at":"$(now_offset 60)","run_started_at":"$(now_offset 60)","updated_at":"$(now_offset 58)"},
 {"id":52,"status":"completed","conclusion":"startup_failure",
  "created_at":"$(now_offset 90)","run_started_at":"$(now_offset 90)","updated_at":"$(now_offset 89)"}]}
EOF
run_case "crash loop stops dispatching" "$TMP/crashloop.json" none

# --- one healthy run in the window -> not a crash loop ----------------------
cat > "$TMP/recovered.json" <<EOF
{"workflow_runs":[
 {"id":60,"status":"completed","conclusion":"success",
  "created_at":"$(now_offset 400)","run_started_at":"$(now_offset 400)","updated_at":"$(now_offset 60)"},
 {"id":61,"status":"completed","conclusion":"failure",
  "created_at":"$(now_offset 500)","run_started_at":"$(now_offset 500)","updated_at":"$(now_offset 499)"},
 {"id":62,"status":"completed","conclusion":"failure",
  "created_at":"$(now_offset 600)","run_started_at":"$(now_offset 600)","updated_at":"$(now_offset 599)"}]}
EOF
run_case "a healthy run clears the crash guard" "$TMP/recovered.json" dispatch

# --- concurrency cancellations must not look like a crash loop --------------
cat > "$TMP/cancelled.json" <<EOF
{"workflow_runs":[
 {"id":70,"status":"completed","conclusion":"cancelled",
  "created_at":"$(now_offset 30)","run_started_at":"$(now_offset 30)","updated_at":"$(now_offset 29)"},
 {"id":71,"status":"completed","conclusion":"cancelled",
  "created_at":"$(now_offset 60)","run_started_at":"$(now_offset 60)","updated_at":"$(now_offset 59)"},
 {"id":72,"status":"completed","conclusion":"cancelled",
  "created_at":"$(now_offset 90)","run_started_at":"$(now_offset 90)","updated_at":"$(now_offset 89)"}]}
EOF
run_case "cancellations are not crash failures" "$TMP/cancelled.json" dispatch

# --- kill switch ------------------------------------------------------------
run_case "kill switch blocks dispatch" "$TMP/empty.json" none DISABLED=true
run_case "kill switch accepts 'yes'"   "$TMP/empty.json" none DISABLED=yes

# --- dispatch rejected -> non-zero exit so the caller can fall back ---------
: > "$TMP/post.log"
if env PATH="$FAKEBIN:$PATH" MOCK_RUNS="$TMP/empty.json" MOCK_POST_CODE=422 \
     POST_LOG="$TMP/post.log" GH_TOKEN=fake REPO=owner/repo \
     bash "$SCRIPT" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "FAIL  rejected dispatch should exit non-zero"
else
  PASS=$((PASS + 1)); echo "PASS  rejected dispatch exits non-zero"
fi

echo
echo "passed ${PASS}, failed ${FAIL}"
[ "$FAIL" -eq 0 ]
