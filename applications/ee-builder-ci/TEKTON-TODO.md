# Tekton Pipelines TODO

**Status**: ⏳ Pending Migration

## Pipelines to Add

The following Tekton resources need to be migrated from the external repository:

### 1. EE Build Pipeline (`ee-build-pipeline.yaml`)
- **Purpose**: Build Execution Environment on every commit
- **Trigger**: Webhook from automation-ee-example repository
- **Tasks**:
  - git-clone
  - validate-ee-definition
  - ansible-builder-create (generate Containerfile)
  - buildah-build
  - trivy-scan (security scanning)
  - push-to-registry (dev tag)

### 2. EE Release Pipeline (`ee-release-pipeline.yaml`)
- **Purpose**: Build and publish EE on tag
- **Trigger**: Git tag push (YY.MM.DD.PATCH format)
- **Tasks**:
  - git-clone
  - validate-version (CalVer format)
  - validate-ee-definition
  - ansible-builder-create
  - buildah-build
  - trivy-scan
  - push-to-registry (version tag + latest)
  - capture-digest (for release manifest)
  - generate-sbom (Software Bill of Materials)

### 3. Tekton Triggers
- `TriggerBinding` for GitHub webhooks
- `TriggerTemplate` for each pipeline
- `EventListener` with GitHub webhook secret

## Secrets Required (HashiCorp Vault)

```yaml
# Reference these from HashiCorp Vault
secrets:
  - github-webhook-secret    # For webhook validation
  - quay-robot-token         # For pushing to Quay.io
  - redhat-registry-token    # For pulling base images from registry.redhat.io
```

## Notes

- Pipelines exist in separate repository, need to be moved here
- Use Buildah for rootless container builds
- SBOM generation required for supply chain security
- Image digest captured and used in release manifest

---
**Last Updated**: 2025-01-05


