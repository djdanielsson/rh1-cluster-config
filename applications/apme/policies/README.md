# RH1 APME organization policies

Central policy configuration for the Ansible Policy & Modernization Engine.

| File | Purpose |
|------|---------|
| `rules.yml` | Rule severity overrides and enable/disable flags |
| `opa/` | Optional OPA Rego bundles for custom org policies |

## Exception process

1. Add a scoped suppression in the content repo: `.apme/suppressions.yml`
2. Open a PR with platform team review for permanent rule changes here
3. Never disable security rules (`R*`) without documented rationale

## CI integration

The `apme-org-policies` ConfigMap is synced into CI namespaces. Tekton copies
`rules.yml` into `.apme/rules.yml` before `apme check` runs.
