#!/usr/bin/env sh
set -eu

: "${PROD_SSH_HOST:?PROD_SSH_HOST is required}"
: "${PROD_SSH_USER:?PROD_SSH_USER is required}"
: "${PROD_SSH_KEY:?PROD_SSH_KEY is required}"
: "${PREVIEW_SERVICE:?PREVIEW_SERVICE is required}"
: "${PREVIEW_PR_NUMBER:?PREVIEW_PR_NUMBER is required}"

keyfile=$(mktemp)

cleanup() {
  rm -f "$keyfile"
}
trap cleanup EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

[ "$PREVIEW_SERVICE" = "www" ] || fail "only www previews are supported"

case "$PREVIEW_PR_NUMBER" in
  ""|*[!0-9]*) fail "PREVIEW_PR_NUMBER must be numeric" ;;
esac

namespace="srvcs-preview-www-pr-${PREVIEW_PR_NUMBER}"
[ "${#namespace}" -le 63 ] || fail "preview namespace is too long"

printf '%s\n' "$PROD_SSH_KEY" >"$keyfile"
chmod 600 "$keyfile"

ssh_base="ssh -i $keyfile -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
remote="$PROD_SSH_USER@$PROD_SSH_HOST"

$ssh_base "$remote" "if command -v k3s >/dev/null 2>&1; then sudo k3s kubectl delete namespace $namespace --ignore-not-found=true --wait=false; else echo 'k3s is not installed; nothing to destroy'; fi"
