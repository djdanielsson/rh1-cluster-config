# OPA policies for APME

Place Rego policy bundles here for organization-specific checks (naming conventions,
production safety, secret patterns in Ansible content).

APME loads OPA policies when configured in the Helm deployment or APME UI Rules
catalog. Tekton PR pipelines copy `rules.yml` into the scanned workspace; OPA
bundles mounted on the APME engine apply during in-cluster scans.
