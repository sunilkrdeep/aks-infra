# GitHub Actions ↔ Azure OIDC (both repos)

## Rule: never store Azure credentials on GitHub

| Store on GitHub? | What | Why |
|------------------|------|-----|
| **Never** | Client secret / password / certificate private key | Real credentials — anyone with them can sign in as the app |
| **Never** | `AZURE_CREDENTIALS` JSON with `clientSecret` | Same as above |
| **Never** | `terraform.tfvars`, `backend.hcl`, `*.tfstate` in git | May contain subscription / secrets |
| **OK (Variables)** | Application (client) ID, Tenant ID, Subscription ID | Public GUIDs — **not** passwords; auth still requires a short-lived OIDC token |

Auth model:

```text
GitHub Actions  --OIDC token-->  Entra ID  --short-lived access token-->  Azure APIs
```

No password is saved in the repo or in GitHub Secrets.

Applies to:

| GitHub repo | Local folder |
|-------------|--------------|
| `aks-infr` (your repo name) | `aks-cluster/` |
| `sample-app` | `sample-app/` |

---

## 1. Create an App Registration (**do not create a client secret**)

```powershell
az login
az account show --query "{subscription:id, tenant:tenantId}" -o json

$APP_NAME = "github-aks-cicd"
$CLIENT_ID = az ad app create --display-name $APP_NAME --query appId -o tsv
az ad sp create --id $CLIENT_ID
$TENANT_ID = az account show --query tenantId -o tsv
$SUBSCRIPTION_ID = az account show --query id -o tsv

Write-Host "CLIENT_ID=$CLIENT_ID"
Write-Host "TENANT_ID=$TENANT_ID"
Write-Host "SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

In Azure Portal → App registrations → your app → **Certificates & secrets**:

- Do **not** click “New client secret”
- Trust comes only from **Federated credentials** (next section)

Grant roles:

```powershell
az role assignment create `
  --assignee $CLIENT_ID `
  --role Contributor `
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# After bootstrap-state has created rg-tfstate:
az role assignment create `
  --assignee $CLIENT_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tfstate"
```

---

## 2. Federated credentials (replaces passwords)

Subjects must match your real repos (`sunilkrdeep` / `aks-infr`):

```powershell
$CLIENT_ID = "<appId>"
$APP_OBJECT_ID = (az ad app show --id $CLIENT_ID --query id -o tsv)

az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "aks-infr-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:sunilkrdeep/aks-infr:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "aks-infr-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:sunilkrdeep/aks-infr:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $APP_OBJECT_ID --parameters '{
  "name": "sample-app-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:sunilkrdeep/sample-app:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

If PowerShell mangles JSON, write each body to a `.json` file and use `@file.json`.

---

## 3. GitHub **Variables only** (no Azure Secrets)

Settings → Secrets and variables → Actions → **Variables** (not Secrets).

### Both repos (`aks-infr` and `sample-app`)

| Variable | Value |
|----------|-------|
| `AZURE_CLIENT_ID` | App **Application (client) ID** |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription GUID |

These are identifiers. Workflows request an OIDC token; Entra exchanges it for a short-lived Azure token. Nothing reusable is stored on GitHub.

### `aks-infr` only (from bootstrap-state)

| Variable | Example |
|----------|---------|
| `TF_STATE_RESOURCE_GROUP` | `rg-tfstate` |
| `TF_STATE_STORAGE_ACCOUNT` | `sttfstate1akc4957` |
| `TF_STATE_CONTAINER` | `tfstate` |
| `TF_STATE_KEY` | `aks-infra.tfstate` |
| `TF_VAR_location` | `southindia` (optional) |
| `TF_VAR_resource_group_name` | `aks-sutramind-rg` (optional) |
| `TF_VAR_cluster_name` | `aks-sutramind` (optional) |
| `TF_VAR_node_count` | `1` (optional) |
| `TF_VAR_node_vm_size` | `Standard_B2s` (optional) |

### `sample-app` only (after Terraform apply)

| Variable | Source |
|----------|--------|
| `ACR_NAME` | `terraform output -raw acr_name` |
| `AKS_RESOURCE_GROUP` | `terraform output -raw resource_group_name` |
| `AKS_CLUSTER_NAME` | `terraform output -raw cluster_name` |

If you already added `AZURE_*` under **Secrets**, delete those secret entries and recreate them as **Variables** so nothing credential-like sits in the secrets store.

---

## 4. Workflow permissions

```yaml
permissions:
  id-token: write   # required for OIDC token
  contents: read
```

Workflows use `azure/login@v2` with `client-id` / `tenant-id` / `subscription-id` from **vars** — never `creds:` / `AZURE_CREDENTIALS`.

---

## 5. Common errors

| Error | Fix |
|-------|-----|
| `AADSTS700016` / federated credential not found | Subject must match exactly (`repo:sunilkrdeep/aks-infr:ref:refs/heads/main`) |
| `AuthorizationFailed` on state | Add **Storage Blob Data Contributor** on `rg-tfstate` |
| `subscription_id must be specified` | Set Variable `AZURE_SUBSCRIPTION_ID` |
| Login looks for a secret | You may still have old workflow expecting Secrets — pull latest workflows that use `vars.*` |
| ACR push denied | Finish aks-infr apply; set `ACR_NAME` on sample-app |
