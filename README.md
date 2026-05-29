# srvcs/infra

The srvcs.cloud production control plane.

This repository owns what is actually live. Service repositories prove that a
service exists and publish OCI images. This repository decides which of those
images are promoted into production and reconciles the infrastructure needed to
serve them.

## Responsibility Split

| Repository | Owns | Does not own |
| --- | --- | --- |
| `srvcs/platform` | Service standard, templates, reusable workflows | Production state |
| `srvcs/www` | Website source and published image | DNS, ingress, runtime allocation |
| `srvcs/infra` | Production infrastructure and promotions | Application implementation |

## Lifecycle

```text
proposed -> implemented -> certified -> published -> deployable -> deployed
```

Most services stop at `deployable`. A service consumes runtime only after it is
added to `promotions/prod/`.

Current production promotions:

| Service | Image | Domains |
| --- | --- | --- |
| `www` | Pinned in `promotions/prod/www.yaml` | `srvcs.cloud`, `www.srvcs.cloud` |

## Production Shape

```text
Cloudflare
  -> proxied A records managed by Terraform
  -> existing VPS
  -> k3s
  -> Traefik ingress
  -> srvcs-www pod
```

Terraform manages Cloudflare DNS. Kubernetes manages the runtime. The existing
VPS is bootstrapped into a single-node k3s cluster.

## Required Secrets

Set these in the `srvcs/infra` GitHub repository before running deployment:

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Terraform provider authentication |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone for `srvcs.cloud` |
| `PROD_ORIGIN_IPV4` | Public IPv4 address of the VPS |
| `PROD_SSH_HOST` | SSH hostname or IP for the VPS |
| `PROD_SSH_USER` | SSH user with sudo access |
| `PROD_SSH_KEY` | Private key for the deploy user |
| `TF_BACKEND_CONFIG_B64` | Base64-encoded Terraform backend config |
| `TF_STATE_ACCESS_KEY_ID` | Access key for the Terraform state backend |
| `TF_STATE_SECRET_ACCESS_KEY` | Secret key for the Terraform state backend |
| `GHCR_READ_USERNAME` | Optional GHCR pull username if the package is private |
| `GHCR_READ_TOKEN` | Optional GHCR read token if the package is private |
| `SRVCS_BOT_TOKEN` | Token used to open promotion PRs, dispatch preview teardown/deploy, and comment preview URLs |

`TF_BACKEND_CONFIG_B64` should contain a backend config matching
`terraform/prod/cloudflare/backend.hcl.example`.

## Validation

```sh
./scripts/validate-control-plane.sh
terraform -chdir=terraform/prod/cloudflare fmt -check
terraform -chdir=terraform/prod/cloudflare init -backend=false
terraform -chdir=terraform/prod/cloudflare validate
kubectl kustomize k8s/prod >/tmp/srvcs-prod.yaml
```

## Production Deployment

The deploy workflow is manual by design:

```text
Actions -> Deploy production -> Run workflow
```

It applies Cloudflare DNS through Terraform, bootstraps k3s on the VPS if needed,
applies Kubernetes manifests, and waits for the `srvcs-www` rollout.

The service image is pinned in two places and validation requires them to match:

- `promotions/prod/www.yaml`
- `k8s/prod/services/www/deployment.yaml`

Update both through a promotion commit.

## Website Preview Workflow

Previews are for maintainer-reviewed `srvcs/www` pull requests. They are not
created for every PR automatically.

1. Open a PR in `srvcs/www` from a branch inside the same repository.
2. Add the `deploy-preview` label.
3. The `srvcs/www` preview workflow builds, tests, and publishes:

   ```text
   ghcr.io/srvcs/www:pr-<number>-<head-sha>
   ```

4. `srvcs/www` dispatches `Deploy preview` in this repository.
5. `srvcs/infra` validates the request, deploys a fixed Kubernetes template,
   and comments the preview URL on the source PR:

   ```text
   https://www-pr-<number>.srvcs.cloud
   ```

6. Removing the `deploy-preview` label or closing the PR dispatches
   `Destroy preview`, which deletes the preview namespace.

Preview namespaces are named:

```text
srvcs-preview-www-pr-<number>
```

Fork PRs are intentionally skipped. A maintainer can move a reviewed change onto
a branch inside `srvcs/www` before adding `deploy-preview`.

Terraform manages a proxied `*.srvcs.cloud` wildcard record for preview
hostnames. Kubernetes still only routes hostnames created by infra's fixed
preview template.

## Website Production Promotion

`srvcs/www` can request a production promotion after its main-branch image is
published.

1. Merge the application PR in `srvcs/www`.
2. `srvcs/www` CI builds, tests, and publishes:

   ```text
   ghcr.io/srvcs/www:<main-commit-sha>
   ```

3. `srvcs/www` dispatches `Promote www` in this repository.
4. `srvcs/infra` updates its own promotion files on a `promote/www-<sha>` branch,
   opens or updates a PR, and runs validation for that branch.
5. Merge the infra promotion PR.
6. Run the manual production deploy workflow:

   ```sh
   gh workflow run deploy-prod.yml --repo srvcs/infra --ref main
   ```

The deploy applies Terraform, applies Kubernetes manifests, and waits for the
`srvcs-www` rollout. Merging the promotion PR records desired state; running
`Deploy production` reconciles live state.

Do not point production at `latest`. Production promotions must pin an immutable
image tag or digest.
