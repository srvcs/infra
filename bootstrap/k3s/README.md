# k3s Bootstrap

This directory contains the one-time host bootstrap for the production VPS.

The script installs a single-node k3s server using the official k3s install
script. It leaves k3s' bundled Traefik ingress enabled so Cloudflare can route
HTTP traffic to the VPS and Traefik can route it to Kubernetes services.

Expected host firewall:

| Port | Purpose |
| --- | --- |
| `22/tcp` | SSH deploy access |
| `80/tcp` | Cloudflare HTTP origin traffic |
| `443/tcp` | Reserved for HTTPS origin traffic |

Do not expose `6443/tcp` publicly unless there is an explicit reason. The deploy
workflow applies manifests by SSHing to the VPS and running `k3s kubectl` on the
host.
