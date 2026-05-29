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
