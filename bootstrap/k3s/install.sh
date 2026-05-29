#!/usr/bin/env sh
set -eu

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed"
  sudo k3s kubectl get nodes
  exit 0
fi

echo "installing k3s"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 600" sh -

echo "waiting for node readiness"
for i in $(seq 1 60); do
  if sudo k3s kubectl get nodes 2>/dev/null | grep -q " Ready "; then
    sudo k3s kubectl get nodes
    exit 0
  fi
  sleep 2
done

echo "k3s node did not become ready" >&2
sudo k3s kubectl get nodes || true
exit 1
