# Tekton Pipelines TODO

**Status**: ⏳ Pending Migration

## Pipelines to Add

The following Tekton resources need to be migrated from the external repository:

### 1. CaC Pipeline (`cac-pipeline.yaml`)
- **Purpose**: Apply AAP Configuration as Code on push to main
- **Trigger**: Webhook from aap-config-as-code repository
- **Tasks**:
  - git-clone
  - ansible-lint
  - run-playbook (with infra.aap_configuration.dispatch)

### 2. CaC PR Validation Pipeline (`cac-pr-validation-pipeline.yaml`)
- **Purpose**: Validate AAP config changes on PR
- **Trigger**: Webhook on PR open/update
- **Tasks**:
  - git-clone
  - ansible-lint
  - yaml-lint
  - validate-credentials (no secrets check)
  - **temp-aap-test** (spin up temp AAP, apply config, validate, tear down)

### 3. Tekton Triggers
- `TriggerBinding` for GitHub webhooks
- `TriggerTemplate` for CaC pipeline
- `EventListener` with GitHub webhook secret

## Secrets Required (HashiCorp Vault)

```yaml
# Reference these from HashiCorp Vault
secrets:
  - aap-dev-api-token     # AAP Dev API token
  - aap-qa-api-token      # AAP QA API token  
  - aap-prod-api-token    # AAP Prod API token
  - github-webhook-secret # For webhook validation
```

## Notes

- Pipelines exist in separate repository, need to be moved here
- Use ExternalSecrets or Vault CSI driver for secret injection
- Temp AAP for testing uses ephemeral namespace pattern

---
**Last Updated**: 2025-01-05

