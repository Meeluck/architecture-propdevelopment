#!/usr/bin/env bash
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-minikube}"
MINIKUBE_HOME="${MINIKUBE_HOME:-$HOME/.minikube}"
CA_CRT="${MINIKUBE_CA_CRT:-$MINIKUBE_HOME/ca.crt}"
CA_KEY="${MINIKUBE_CA_KEY:-$MINIKUBE_HOME/ca.key}"
CERT_DAYS="${CERT_DAYS:-365}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/generated-users}"
SERIAL_FILE="$OUT_DIR/ca.srl"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is not installed: $1" >&2
    exit 1
  fi
}

require_command kubectl
require_command minikube
require_command openssl

if ! minikube -p "$PROFILE" status >/dev/null 2>&1; then
  echo "Minikube profile '$PROFILE' is not running. Start it first: minikube start -p $PROFILE" >&2
  exit 1
fi

minikube -p "$PROFILE" update-context >/dev/null

if [ ! -f "$CA_CRT" ] || [ ! -f "$CA_KEY" ]; then
  echo "Minikube CA files were not found: $CA_CRT, $CA_KEY" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

if [ ! -f "$SERIAL_FILE" ]; then
  echo "1000" >"$SERIAL_FILE"
fi

CLUSTER_NAME="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || true)"
if [ -z "$CLUSTER_NAME" ]; then
  CLUSTER_NAME="$PROFILE"
fi

create_user() {
  local username="$1"
  local groups_csv="$2"
  local user_dir="$OUT_DIR/$username"
  local key="$user_dir/$username.key"
  local csr="$user_dir/$username.csr"
  local crt="$user_dir/$username.crt"
  local subject="/CN=$username"
  local old_ifs="$IFS"

  mkdir -p "$user_dir"
  chmod 700 "$user_dir"

  IFS=","
  set -- $groups_csv
  IFS="$old_ifs"

  for group in "$@"; do
    subject="$subject/O=$group"
  done

  openssl genrsa -out "$key" 2048 >/dev/null 2>&1
  openssl req -new -key "$key" -out "$csr" -subj "$subject" >/dev/null 2>&1
  openssl x509 -req \
    -in "$csr" \
    -CA "$CA_CRT" \
    -CAkey "$CA_KEY" \
    -CAserial "$SERIAL_FILE" \
    -out "$crt" \
    -days "$CERT_DAYS" \
    -sha256 >/dev/null 2>&1
  chmod 600 "$key"

  kubectl config set-credentials "$username" \
    --client-certificate="$crt" \
    --client-key="$key" \
    --embed-certs=true >/dev/null
  kubectl config set-context "$username@$CLUSTER_NAME" \
    --cluster="$CLUSTER_NAME" \
    --user="$username" >/dev/null

  echo "Created user '$username' with groups '$groups_csv'. Context: $username@$CLUSTER_NAME"
}

create_user "ivan.viewer" "propdev-viewers"
create_user "maria.owner-dev" "owner-services-team,smart-home-team"
create_user "dmitry.crm-dev" "crm-team"
create_user "pavel.platform-admin" "propdev-platform-admins"
create_user "olga.security-admin" "propdev-security-admins"

echo "User certificates are stored in: $OUT_DIR"
echo "Next steps: run ./02-create-roles.sh and ./03-bind-users-roles.sh"
