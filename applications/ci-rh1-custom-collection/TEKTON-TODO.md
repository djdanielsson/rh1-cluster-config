# Tekton Pipelines TODO

**Status**: ⏳ Pending Migration

## Pipelines to Add

The following Tekton resources need to be migrated from the external repository:

### 1. Collection CI Pipeline (`collection-ci-pipeline.yaml`)
- **Purpose**: Test Ansible collections on every commit
- **Trigger**: Webhook from automation-collection-example repository
- **Tasks**:
  - git-clone
  - ansible-lint
  - ansible-test-sanity
  - ansible-test-units
  - molecule-test (matrix for all scenarios)

### 2. Collection PR Validation Pipeline (`collection-pr-validation-pipeline.yaml`)
- **Purpose**: Validate collection changes on PR
- **Trigger**: Webhook on PR open/update
- **Tasks**:
  - git-clone
  - ansible-lint
  - python-lint (black, isort, flake8)
  - molecule-test
  - collection-build (validate it builds)

### 3. Collection Release Pipeline (`collection-release-pipeline.yaml`)
- **Purpose**: Build and publish collection on tag
- **Trigger**: Git tag push (YY.MM.DD.PATCH format)
- **Tasks**:
  - git-clone
  - validate-version (CalVer format)
  - ansible-lint
  - molecule-test
  - collection-build
  - collection-publish (to Automation Hub or Galaxy)

### 4. Tekton Triggers
- `TriggerBinding` for GitHub webhooks
- `TriggerTemplate` for each pipeline
- `EventListener` with GitHub webhook secret

## Secrets Required (HashiCorp Vault)

```yaml
# Reference these from HashiCorp Vault
secrets:
  - github-webhook-secret   # For webhook validation
  - automation-hub-token    # For publishing to Automation Hub
  - galaxy-api-key          # For publishing to Galaxy (optional)
```

## Notes

- Pipelines exist in separate repository, need to be moved here
- Use Podman-in-Podman for Molecule container tests
- Matrix strategy for testing multiple Molecule scenarios in parallel

---
**Last Updated**: 2025-01-05

