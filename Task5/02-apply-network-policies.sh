#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="${POLICY_FILE:-$SCRIPT_DIR/non-admin-api-allow.yaml}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is not installed: $1" >&2
    exit 1
  fi
}

require_command kubectl

if [ ! -f "$POLICY_FILE" ]; then
  echo "NetworkPolicy file was not found: $POLICY_FILE" >&2
  exit 1
fi

kubectl apply -f "$POLICY_FILE"

echo "Network policies were applied from: $POLICY_FILE"
kubectl -n traffic-demo get networkpolicies
