#!/usr/bin/env bash
# One-time setup, run by an Azure admin with the az CLI:
#   1. Storage account for Terraform state (Entra auth, no access keys)
#   2. Entra app + service principal that GitHub Actions uses through OIDC (no client secret)
#   3. Federated credentials for the repo's GitHub environments
#   4. Role assignments for that identity
#
# Usage: ./scripts/bootstrap-azure.sh <github-owner/repo> [location]
set -euo pipefail

REPO="${1:?usage: $0 <github-owner/repo> [location]}"
LOCATION="${2:-francecentral}"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
STATE_RG="rg-threetier-tfstate"
STATE_SA="stthreetier$(openssl rand -hex 3)"
APP_NAME="gh-oidc-${REPO//\//-}"

echo "==> Terraform state: $STATE_RG / $STATE_SA"
az group create -n "$STATE_RG" -l "$LOCATION" -o none
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
  --sku Standard_ZRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false -o none
az storage account blob-service-properties update --account-name "$STATE_SA" -g "$STATE_RG" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 30 -o none
az storage container create --account-name "$STATE_SA" -n tfstate --auth-mode login -o none

echo "==> GitHub OIDC identity: $APP_NAME"
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
SP_ID="$(az ad sp create --id "$APP_ID" --query id -o tsv 2>/dev/null || az ad sp show --id "$APP_ID" --query id -o tsv)"

for subject in \
  "repo:${REPO}:environment:dev" \
  "repo:${REPO}:environment:prod" \
  "repo:${REPO}:environment:dev-plan" \
  "repo:${REPO}:environment:prod-plan"; do
  name="$(echo "$subject" | tr ':/' '--')"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${name:0:120}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${subject}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" -o none
done

echo "==> Role assignments"
# Owner is needed because Terraform creates role assignments (AcrPull, Key Vault, AKS RBAC).
# Tighten to Contributor + User Access Administrator (with conditions) if your policy requires.
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role Owner --scope "/subscriptions/$SUBSCRIPTION_ID" -o none
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)" -o none

sed -i.bak "s/REPLACE_WITH_STATE_ACCOUNT/$STATE_SA/" infra/terraform/environments/*.backend.hcl && rm -f infra/terraform/environments/*.bak

cat <<EOF

Done. Add these as repository (or environment) secrets in GitHub:
  AZURE_CLIENT_ID       = $APP_ID
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID

Create GitHub environments: dev, prod (add required reviewers), dev-plan, prod-plan.
On environments dev and prod, add a variable APP_HOST (e.g. dev.example.com / app.example.com).

infra/terraform/environments/*.backend.hcl now point at $STATE_SA — commit that change.
EOF
