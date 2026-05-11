#!/usr/bin/env bash
set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is not installed: $1" >&2
    exit 1
  fi
}

require_command kubectl

kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-viewers-readonly
subjects:
  - kind: Group
    name: propdev-viewers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-readonly
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-platform-admins-configurator
subjects:
  - kind: Group
    name: propdev-platform-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-platform-configurator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-platform-admins-readonly
subjects:
  - kind: Group
    name: propdev-platform-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-readonly
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-security-admins-secret-manager
subjects:
  - kind: Group
    name: propdev-security-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-secret-manager
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdev-security-admins-readonly
subjects:
  - kind: Group
    name: propdev-security-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: propdev-readonly
  apiGroup: rbac.authorization.k8s.io
YAML

bind_namespace_team() {
  local namespace="$1"
  local group="$2"
  local binding_name="propdev-${group}-namespace-configurator"

  kubectl -n "$namespace" create rolebinding "$binding_name" \
    --clusterrole=propdev-namespace-configurator \
    --group="$group" \
    --dry-run=client \
    -o yaml | kubectl apply -f -
}

bind_namespace_team "owner-services" "owner-services-team"
bind_namespace_team "crm" "crm-team"
bind_namespace_team "smart-home" "smart-home-team"
bind_namespace_team "data-platform" "data-platform-team"
bind_namespace_team "finance" "finance-team"

echo "Role bindings were created or updated."
echo "Check examples:"
echo "  kubectl auth can-i get pods -A --as=ivan.viewer --as-group=propdev-viewers"
echo "  kubectl auth can-i get secrets -A --as=ivan.viewer --as-group=propdev-viewers"
echo "  kubectl auth can-i create deployment -n smart-home --as=maria.owner-dev --as-group=smart-home-team"
echo "  kubectl auth can-i get secrets -A --as=olga.security-admin --as-group=propdev-security-admins"
