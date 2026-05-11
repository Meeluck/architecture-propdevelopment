#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-traffic-demo}"
IMAGE="${IMAGE:-nginx}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is not installed: $1" >&2
    exit 1
  fi
}

require_command kubectl

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

create_app() {
  local app_name="$1"
  local role="$2"

  kubectl -n "$NAMESPACE" run "$app_name" \
    --image="$IMAGE" \
    --labels="app=$app_name,role=$role" \
    --expose \
    --port=80 \
    --dry-run=client \
    -o yaml | kubectl apply -f -
}

create_app "front-end-app" "front-end"
create_app "back-end-api-app" "back-end-api"
create_app "admin-front-end-app" "admin-front-end"
create_app "admin-back-end-api-app" "admin-back-end-api"

kubectl -n "$NAMESPACE" wait --for=condition=Ready pod \
  -l role=front-end \
  --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod \
  -l role=back-end-api \
  --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod \
  -l role=admin-front-end \
  --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod \
  -l role=admin-back-end-api \
  --timeout=120s

echo "Nginx pods and services were created in namespace '$NAMESPACE'."
kubectl -n "$NAMESPACE" get pods,services --show-labels
