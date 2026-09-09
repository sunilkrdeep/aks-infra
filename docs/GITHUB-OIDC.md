# GitHub Actions ↔ Azure OIDC (both repos)

Use **OpenID Connect** so GitHub Actions get short-lived Azure tokens. No long-lived client secrets in GitHub.

Applies to:

| GitHub repo | Local folder |
|-------------|--------------|
| `aks-infra` | `aks-cluster/` |
| `sample-app` | `sample-app/` |

---

## 1. Create an App Registration

```powershell
az login
az account show --query "{subscription:id, tenant:tenantId}" -o json

# Create app + service principal
$APP_NAME = "github-aks-cicd"
az ad app create --display-name $APP_NAME --query appId -o tsv
# Save CLIENT_ID from output
$CLIENT_ID = "<paste-appId>"

az ad sp create --id $CLIENT_ID
$TENANT_ID = (az account show --query tenantId -o tsv)
$SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

Grant roles (lab-friendly; tighten later in production):

```powershell
# Create / manage AKS, ACR, networking
az role assignment create `
  --assignee $CLIENT_ID `
  --role Contributor `
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Read/write Terraform state blobs (after bootstrap-state)
az role assignment create `
  --assignee $CLIENT_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tfstate"
```

Also ensure the identity can use Azure AD for storage (`use_azuread_auth = true`). Contributor on the storage account RG is usually enough together with Blob Data Contributor.

---

## 2. Federated credentials (two repos)

Replace `YOUR_ORG` with your GitHub user or org. Replace app object id if your CLI version requires it.

```powershell
$CLIENT_ID = "<appId>"
$APP_OBJECT_ID = (az ad app show --id $CLIENT_ID --query id -o tsv)

# --- aks-infra: pushes to main ---
az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "aks-infra-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_ORG/aks-infra:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# --- aks-infra: pull requests (terraform plan) ---
az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "aks-infra-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_ORG/aks-infra:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# --- sample-app: pushes to main ---
az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "sample-app-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_ORG/sample-app:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

On Windows PowerShell, if JSON quoting fails, write each body to a temp `.json` file and pass `@file.json`.

---

## 3. GitHub Secrets (both repos)

Settings → Secrets and variables → Actions → **Secrets**:

| Name | Value |
|------|-------|
| `AZURE_CLIENT_ID` | App registration **Application (client) ID** |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription GUID |

Via CLI:

```powershell
gh secret set AZURE_CLIENT_ID -b "$CLIENT_ID" -R YOUR_ORG/aks-infra
gh secret set AZURE_TENANT_ID -b "$TENANT_ID" -R YOUR_ORG/aks-infra
gh secret set AZURE_SUBSCRIPTION_ID -b "$SUBSCRIPTION_ID" -R YOUR_ORG/aks-infra

gh secret set AZURE_CLIENT_ID -b "$CLIENT_ID" -R YOUR_ORG/sample-app
gh secret set AZURE_TENANT_ID -b "$TENANT_ID" -R YOUR_ORG/sample-app
gh secret set AZURE_SUBSCRIPTION_ID -b "$SUBSCRIPTION_ID" -R YOUR_ORG/sample-app
```

---

## 4. GitHub Variables

### `aks-infra` (from `bootstrap-state` output)

| Variable | Example |
|----------|---------|
| `TF_STATE_RESOURCE_GROUP` | `rg-tfstate` |
| `TF_STATE_STORAGE_ACCOUNT` | `sttfstatea1b2c3d4` |
| `TF_STATE_CONTAINER` | `tfstate` |
| `TF_STATE_KEY` | `aks-infra.tfstate` |
| `TF_VAR_location` | `southindia` (optional) |
| `TF_VAR_resource_group_name` | `aks-sutramind-rg` (optional) |
| `TF_VAR_cluster_name` | `aks-sutramind` (optional) |
| `TF_VAR_node_count` | `2` (optional) |
| `TF_VAR_node_vm_size` | `Standard_D2s_v3` (optional) |

```powershell
gh variable set TF_STATE_RESOURCE_GROUP -b "rg-tfstate" -R YOUR_ORG/aks-infra
# …repeat for other TF_STATE_* and optional TF_VAR_*
```

### `sample-app` (from `terraform output` after infra apply)

| Variable | Source |
|----------|--------|
| `ACR_NAME` | `terraform output -raw acr_name` |
| `AKS_RESOURCE_GROUP` | `terraform output -raw resource_group_name` |
| `AKS_CLUSTER_NAME` | `terraform output -raw cluster_name` |
| `IMAGE_NAME` | `sample-app` (optional) |

---

## 5. Workflow permissions

Both workflows already set:

```yaml
permissions:
  id-token: write   # required for OIDC
  contents: read
```

Do not disable “Allow GitHub Actions to create and approve pull requests” if you want plan comments; the infra workflow also uses `pull-requests: write`.

---

## 6. Common errors

| Error | Fix |
|-------|-----|
| `AADSTS700016` / federated credential not found | Subject must match exactly (`repo:org/name:ref:refs/heads/main`) |
| `AuthorizationFailed` on state | Add **Storage Blob Data Contributor** on `rg-tfstate` |
| `subscription_id must be specified` | Ensure `AZURE_SUBSCRIPTION_ID` secret is set (maps to `TF_VAR_subscription_id`) |
| ACR push denied | Wait until aks-infra apply finishes; confirm `ACR_NAME` variable |
| AKS pull ImagePullBackOff | Confirm `AcrPull` role on kubelet (created by Terraform `acr.tf`) |
