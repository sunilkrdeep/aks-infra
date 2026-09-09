#!/usr/bin/env bash
# One-time bootstrap: Azure Storage for Terraform remote state.
set -euo pipefail

LOCATION="${LOCATION:-southindia}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-tfstate}"
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"
STATE_KEY="${STATE_KEY:-aks-infra.tfstate}"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) not found." >&2
  exit 1
fi

echo "Using subscription:"
az account show --query "{name:name, id:id}" -o table

SUFFIX=$(head -c 32 /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
STORAGE_ACCOUNT_NAME="sttfstate${SUFFIX}"

echo "Creating resource group ${RESOURCE_GROUP_NAME} in ${LOCATION} ..."
az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}" --output none

echo "Creating storage account ${STORAGE_ACCOUNT_NAME} ..."
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output none

echo "Creating container ${CONTAINER_NAME} ..."
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --auth-mode login \
  --output none

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_PATH="${ROOT}/backend.hcl"
cat > "${BACKEND_PATH}" <<EOF
resource_group_name  = "${RESOURCE_GROUP_NAME}"
storage_account_name = "${STORAGE_ACCOUNT_NAME}"
container_name       = "${CONTAINER_NAME}"
key                  = "${STATE_KEY}"
use_azuread_auth     = true
EOF

echo ""
echo "Wrote ${BACKEND_PATH}"
echo ""
echo "Next steps:"
echo "  1. terraform init -backend-config=backend.hcl"
echo "  2. Add these as GitHub Variables on aks-infra:"
echo "       TF_STATE_RESOURCE_GROUP = ${RESOURCE_GROUP_NAME}"
echo "       TF_STATE_STORAGE_ACCOUNT = ${STORAGE_ACCOUNT_NAME}"
echo "       TF_STATE_CONTAINER = ${CONTAINER_NAME}"
echo "       TF_STATE_KEY = ${STATE_KEY}"
