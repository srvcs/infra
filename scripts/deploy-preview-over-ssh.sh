#!/usr/bin/env sh
set -eu

: "${PROD_SSH_HOST:?PROD_SSH_HOST is required}"
: "${PROD_SSH_USER:?PROD_SSH_USER is required}"
: "${PROD_SSH_KEY:?PROD_SSH_KEY is required}"
: "${PREVIEW_SERVICE:?PREVIEW_SERVICE is required}"
: "${PREVIEW_PR_NUMBER:?PREVIEW_PR_NUMBER is required}"
: "${PREVIEW_IMAGE:?PREVIEW_IMAGE is required}"
: "${PREVIEW_SOURCE_SHA:?PREVIEW_SOURCE_SHA is required}"

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workdir="/tmp/srvcs-infra-preview"
keyfile=$(mktemp)
manifest=$(mktemp)

cleanup() {
  rm -f "$keyfile" "$manifest"
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

printf '%s' "$PREVIEW_SOURCE_SHA" | grep -Eq '^[0-9a-f]{40}$' || fail "PREVIEW_SOURCE_SHA must be a 40-character git SHA"
printf '%s' "$PREVIEW_IMAGE" | grep -Eq "^ghcr\\.io/srvcs/www:pr-${PREVIEW_PR_NUMBER}-[0-9a-f]{40}$" || fail "PREVIEW_IMAGE must be the approved preview tag shape"

namespace="srvcs-preview-www-pr-${PREVIEW_PR_NUMBER}"
host="www-pr-${PREVIEW_PR_NUMBER}.srvcs.cloud"

[ "${#namespace}" -le 63 ] || fail "preview namespace is too long"

cat >"$manifest" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
  labels:
    app.kubernetes.io/part-of: srvcs
    srvcs.cloud/environment: preview
    srvcs.cloud/service: www
    srvcs.cloud/pr: "${PREVIEW_PR_NUMBER}"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: srvcs-www
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: srvcs-www
    app.kubernetes.io/part-of: srvcs
automountServiceAccountToken: false
---
apiVersion: v1
kind: Service
metadata:
  name: srvcs-www
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: srvcs-www
    app.kubernetes.io/part-of: srvcs
    srvcs.cloud/service: www
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: srvcs-www
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: srvcs-www
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: srvcs-www
    app.kubernetes.io/part-of: srvcs
    srvcs.cloud/service: www
    srvcs.cloud/environment: preview
  annotations:
    srvcs.cloud/source-sha: "${PREVIEW_SOURCE_SHA}"
    srvcs.cloud/image: "${PREVIEW_IMAGE}"
spec:
  replicas: 1
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: srvcs-www
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: srvcs-www
        app.kubernetes.io/part-of: srvcs
        srvcs.cloud/service: www
        srvcs.cloud/environment: preview
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: /metrics
        prometheus.io/port: "8080"
    spec:
      serviceAccountName: srvcs-www
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        runAsGroup: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: srvcs-www
          image: "${PREVIEW_IMAGE}"
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: SRVCS_ENV
              value: preview
            - name: SRVCS_BIND_ADDR
              value: 0.0.0.0:8080
            - name: RUST_LOG
              value: info,tower_http=info
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 15
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: 10m
              memory: 48Mi
            limits:
              cpu: 150m
              memory: 96Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: srvcs-www
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: srvcs-www
    app.kubernetes.io/part-of: srvcs
    srvcs.cloud/service: www
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: srvcs-www
                port:
                  name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: srvcs-www-secure
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: srvcs-www
    app.kubernetes.io/part-of: srvcs
    srvcs.cloud/service: www
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - ${host}
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: srvcs-www
                port:
                  name: http
EOF

printf '%s\n' "$PROD_SSH_KEY" >"$keyfile"
chmod 600 "$keyfile"

ssh_base="ssh -i $keyfile -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
scp_base="scp -i $keyfile -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
remote="$PROD_SSH_USER@$PROD_SSH_HOST"

$ssh_base "$remote" "rm -rf $workdir && mkdir -p $workdir"
$scp_base -r "$root/bootstrap" "$remote:$workdir/"
$scp_base "$manifest" "$remote:$workdir/preview.yaml"

$ssh_base "$remote" "chmod +x $workdir/bootstrap/k3s/install.sh && $workdir/bootstrap/k3s/install.sh"
$ssh_base "$remote" "sudo k3s kubectl apply -f $workdir/preview.yaml"
$ssh_base "$remote" "sudo k3s kubectl -n $namespace rollout status deployment/srvcs-www --timeout=180s"
$ssh_base "$remote" "sudo k3s kubectl -n $namespace get deploy,svc,ingress"

echo "preview_url=https://${host}"
