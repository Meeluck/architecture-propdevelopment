#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-traffic-demo}"
TEST_IMAGE="${TEST_IMAGE:-alpine:3.20}"
FAILURES=0

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is not installed: $1" >&2
    exit 1
  fi
}

require_command kubectl

run_check() {
  local from_role="$1"
  local target_service="$2"
  local expected="$3"
  local description="$4"
  local pod_name
  local result

  pod_name="test-${from_role}-${RANDOM}"

  echo
  echo "Check: $description"
  echo "From role '$from_role' to service '$target_service'. Expected: $expected"

  if kubectl -n "$NAMESPACE" run "$pod_name" \
    --rm \
    -i \
    --restart=Never \
    --image="$TEST_IMAGE" \
    --labels="app=traffic-test,role=$from_role" \
    --command -- sh -c "wget -qO- -T 2 http://$target_service >/dev/null"; then
    result="allow"
  else
    result="deny"
  fi

  if [ "$result" = "$expected" ]; then
    echo "PASS: got $result"
  else
    echo "FAIL: got $result, expected $expected" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

kubectl -n "$NAMESPACE" get pods,services,networkpolicies >/dev/null

run_check "front-end" "back-end-api-app" "allow" \
  "public UI can call public API"
run_check "back-end-api" "front-end-app" "allow" \
  "public API can call public UI"
run_check "admin-front-end" "admin-back-end-api-app" "allow" \
  "admin UI can call admin API"
run_check "admin-back-end-api" "admin-front-end-app" "allow" \
  "admin API can call admin UI"
run_check "front-end" "admin-back-end-api-app" "deny" \
  "public UI cannot call admin API"
run_check "admin-front-end" "back-end-api-app" "deny" \
  "admin UI cannot call public API"
run_check "back-end-api" "admin-back-end-api-app" "deny" \
  "public API cannot call admin API"
run_check "unknown-client" "back-end-api-app" "deny" \
  "pod without an allowed role cannot call public API"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All network policy checks passed."
else
  echo "$FAILURES network policy check(s) failed." >&2
  exit 1
fi
