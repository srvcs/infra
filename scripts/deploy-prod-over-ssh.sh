#!/usr/bin/env sh
set -eu

: "${PROD_SSH_HOST:?PROD_SSH_HOST is required}"
: "${PROD_SSH_USER:?PROD_SSH_USER is required}"
: "${PROD_SSH_KEY:?PROD_SSH_KEY is required}"

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workdir="/tmp/srvcs-infra-deploy"
keyfile=$(mktemp)

cleanup() {
  rm -f "$keyfile"
}
trap cleanup EXIT

printf '%s\n' "$PROD_SSH_KEY" >"$keyfile"
chmod 600 "$keyfile"

ssh_base="ssh -i $keyfile -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
scp_base="scp -i $keyfile -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
remote="$PROD_SSH_USER@$PROD_SSH_HOST"

$ssh_base "$remote" "rm -rf $workdir && mkdir -p $workdir"
$scp_base -r "$root/bootstrap" "$root/k8s" "$remote:$workdir/"

$ssh_base "$remote" "chmod +x $workdir/bootstrap/k3s/install.sh && $workdir/bootstrap/k3s/install.sh"
$ssh_base "$remote" "sudo k3s kubectl apply -f $workdir/k8s/prod/namespace.yaml"

if [ "${GHCR_READ_USERNAME:-}" ] && [ "${GHCR_READ_TOKEN:-}" ]; then
  $ssh_base "$remote" "sudo k3s kubectl -n srvcs-prod create secret docker-registry ghcr-pull \
    --docker-server=ghcr.io \
    --docker-username='$GHCR_READ_USERNAME' \
    --docker-password='$GHCR_READ_TOKEN' \
    --dry-run=client -o yaml | sudo k3s kubectl apply -f -"
else
  echo "GHCR pull credentials not provided; assuming ghcr.io/srvcs/www is public or secret already exists"
fi

$ssh_base "$remote" "sudo k3s kubectl apply -k $workdir/k8s/prod"
$ssh_base "$remote" "sudo k3s kubectl -n srvcs-prod rollout status deployment/srvcs-www --timeout=180s"
$ssh_base "$remote" "sudo k3s kubectl -n srvcs-prod get deploy,svc,ingress"
