#!/usr/bin/env bash
#
# vault-bootstrap.sh
# Bootstrap HashiCorp Vault paths, policies, and auth methods for the RH1 platform.
#
# Prerequisites:
#   - vault CLI authenticated with root/admin token
#   VAULT_ADDR set (e.g. http://vault.apps.cluster.example.com)
#
# Usage:
#   export VAULT_ADDR=https://vault.example.com
#   export VAULT_TOKEN=<root-token>
#   ./scripts/vault-bootstrap.sh
#
set -euo pipefail

echo "=== RH1 Vault Bootstrap ==="

vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV v2 already enabled at secret/"

echo "Writing platform policies..."
vault policy write rh1-platform-read - <<'EOF'
path "secret/data/rh1/platform/*" {
  capabilities = ["read"]
}
EOF

vault policy write rh1-ci-tekton - <<'EOF'
path "secret/data/rh1/platform/ci/*" {
  capabilities = ["read"]
}
path "secret/data/rh1/platform/signing/*" {
  capabilities = ["read"]
}
path "secret/data/rh1/platform/aap/*" {
  capabilities = ["read"]
}
EOF

vault policy write rh1-aap-dev-read - <<'EOF'
path "secret/data/rh1/automation/*" {
  capabilities = ["read"]
}
path "secret/data/rh1/platform/aap/dev/*" {
  capabilities = ["read"]
}
EOF

vault policy write rh1-aap-qa-read - <<'EOF'
path "secret/data/rh1/automation/*" {
  capabilities = ["read"]
}
path "secret/data/rh1/platform/aap/qa/*" {
  capabilities = ["read"]
}
EOF

vault policy write rh1-aap-prod-read - <<'EOF'
path "secret/data/rh1/automation/machine/linux/prod" {
  capabilities = ["read"]
}
path "secret/data/rh1/automation/scm/github" {
  capabilities = ["read"]
}
path "secret/data/rh1/automation/registry/quay" {
  capabilities = ["read"]
}
path "secret/data/rh1/platform/aap/prod/*" {
  capabilities = ["read"]
}
EOF

echo "Seeding placeholder secret paths (replace values after import)..."
vault kv put secret/rh1/platform/signing/cosign \
  cosign_key="REPLACE_ME" cosign_pub="REPLACE_ME" password=""
vault kv put secret/rh1/platform/signing/galaxy-gpg \
  pubring_kbx="REPLACE_ME" trusted_asc="REPLACE_ME"
vault kv put secret/rh1/platform/signing/hub-collection \
  private_key="REPLACE_ME" public_key="REPLACE_ME"
vault kv put secret/rh1/platform/ci/github \
  username="git" password="REPLACE_ME"
vault kv put secret/rh1/platform/ci/quay-ee \
  username="REPLACE_ME" password="REPLACE_ME" token="REPLACE_ME" dockerconfigjson="REPLACE_ME"
vault kv put secret/rh1/platform/ci/automationhub \
  token="REPLACE_ME" server="REPLACE_ME"
vault kv put secret/rh1/platform/aap/dev/admin-password password="REPLACE_ME"
vault kv put secret/rh1/platform/aap/qa/admin-password password="REPLACE_ME"
vault kv put secret/rh1/platform/aap/prod/admin-password password="REPLACE_ME"
vault kv put secret/rh1/automation/scm/github \
  username="git" password="REPLACE_ME"
vault kv put secret/rh1/automation/registry/quay \
  host="quay.io" username="REPLACE_ME" password="REPLACE_ME"

if [ -n "${IMPORT_SIGNING_DIR:-}" ] && [ -d "${IMPORT_SIGNING_DIR}" ]; then
  echo "Importing signing secrets from ${IMPORT_SIGNING_DIR}..."
  vault kv put secret/rh1/platform/signing/cosign \
    cosign_key=@"${IMPORT_SIGNING_DIR}/cosign.key" \
    cosign_pub=@"${IMPORT_SIGNING_DIR}/cosign.pub" \
    password=@"${IMPORT_SIGNING_DIR}/cosign.password" 2>/dev/null || true
fi

echo "Enabling Kubernetes auth (configure cluster binding separately)..."
vault auth enable kubernetes 2>/dev/null || echo "kubernetes auth already enabled"

echo "Enabling JWT auth for AAP OIDC (configure discovery URL after AAP OIDC is enabled)..."
vault auth enable jwt 2>/dev/null || echo "jwt auth already enabled"

echo "Enabling audit device..."
vault audit enable file file_path=/vault/audit/audit.log 2>/dev/null || echo "audit already enabled"

echo ""
echo "=== Bootstrap complete ==="
echo "Next steps:"
echo "  1. Run applications/hashicorp-vault vault-kubernetes-auth ConfigMap script"
echo "  2. Enable AAP FEATURE_OIDC_WORKLOAD_IDENTITY_ENABLED"
echo "  3. Run vault-jwt-auth ConfigMap script with AAP_URL set"
echo "  4. Replace REPLACE_ME values in Vault paths with production secrets"
