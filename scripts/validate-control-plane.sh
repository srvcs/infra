#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [ -f "$root/$1" ] || fail "missing $1"
}

require_file catalog/services/www.yaml
require_file promotions/prod/www.yaml
require_file k8s/prod/services/www/deployment.yaml
require_file terraform/prod/cloudflare/main.tf

promotion_image=$(awk '/^[[:space:]]*image: / { print $2; exit }' "$root/promotions/prod/www.yaml")
deployment_image=$(awk '/^[[:space:]]*image: / { print $2; exit }' "$root/k8s/prod/services/www/deployment.yaml")

[ -n "$promotion_image" ] || fail "promotion image not found"
[ -n "$deployment_image" ] || fail "deployment image not found"
[ "$promotion_image" = "$deployment_image" ] || fail "promotion image ($promotion_image) does not match deployment image ($deployment_image)"

case "$promotion_image" in
  *:latest) fail "production promotion must not use :latest" ;;
esac

grep -q 'status: deployable' "$root/catalog/services/www.yaml" || fail "www is not marked deployable in catalog"
grep -q 'srvcs.cloud' "$root/promotions/prod/www.yaml" || fail "www promotion does not declare srvcs.cloud"
grep -q 'srvcs.cloud' "$root/k8s/prod/services/www/ingress.yaml" || fail "www ingress does not route srvcs.cloud"

echo "control plane validation passed"
