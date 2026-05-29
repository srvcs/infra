# Governance

Production is a runtime allocation, not a birthright.

The platform can certify a service as deployable. The infra repository promotes
only the services that have a reason to consume runtime.

## Promotion Rules

1. A service must publish an OCI image through the shared platform workflow.
2. The image must be pinned by immutable tag or digest.
3. The service must appear in `catalog/services/`.
4. The production allocation must appear in `promotions/prod/`.
5. Kubernetes manifests must expose liveness, readiness, metrics, and OpenAPI
   endpoints where the service standard requires them.

## Current Exception

`www` is promoted because `srvcs.cloud` needs a public website. This does not
create a general right for every service to be deployed.

## Preview Rules

Preview runtime is also allocated by infra, not by service repositories.

1. A preview must be requested through an infra workflow.
2. The source PR must carry the `deploy-preview` maintainer label.
3. The source image must use the approved preview tag shape:
   `ghcr.io/srvcs/www:pr-<number>-<sha>`.
4. The preview namespace, hostname, ports, probes, security context, and resource
   limits are derived by infra. PR authors do not provide Kubernetes manifests.
5. Preview namespaces are deleted when the source PR closes or the
   `deploy-preview` label is removed.
