# aks-infra (GitHub) — AKS + ACR via Terraform CI/CD

**GitHub Free is enough** for this lab (no paid plan). Sign up at https://github.com/signup then follow [docs/GITHUB-BOOTSTRAP.md](docs/GITHUB-BOOTSTRAP.md).

Companion app repo: **`sample-app`** (build image → push ACR → deploy to AKS).

**New to Terraform?** Read [docs/TERRAFORM-GUIDE.md](docs/TERRAFORM-GUIDE.md).  
**Enterprise CI/CD & Branching Guide:** [docs/CICD_PIPELINE_DOCUMENTATION.md](docs/CICD_PIPELINE_DOCUMENTATION.md)  
**GitHub + OIDC setup:** [docs/GITHUB-OIDC.md](docs/GITHUB-OIDC.md)  
**Create repos and first push:** [docs/GITHUB-BOOTSTRAP.md](docs/GITHUB-BOOTSTRAP.md)

---

## What Terraform creates

```text
Subscription
├── rg-tfstate (bootstrap script — not in this Terraform)
│     └── Storage account + tfstate container
└── Resource Group  (e.g. aks-sutramind-rg)
      ├── Virtual Network + subnet
      ├── AKS cluster (Azure-managed control plane + worker VMs)
      └── Azure Container Registry + AcrPull for AKS nodes
```

---

## Prerequisites

1. Terraform CLI `>= 1.5`
2. Azure CLI + `az login`
3. GitHub account + [`gh`](https://cli.github.com/) (optional but recommended)
4. One-time remote state: `.\scripts\bootstrap-state.ps1` (or `bash scripts/bootstrap-state.sh`)

---

## Local workflow (optional)

```powershell
cd aks-cluster

copy terraform.tfvars.example terraform.tfvars
# set subscription_id, location, cluster_name, …

.\scripts\bootstrap-state.ps1   # once
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply, note outputs for the app repo:

```powershell
terraform output acr_name
terraform output resource_group_name
terraform output cluster_name
terraform output acr_login_server
```

---

## CI/CD (GitHub Actions)

| Event | Action |
|-------|--------|
| Pull request to `main` | `terraform plan` (+ PR comment) |
| Push to `main` | `terraform apply` |

Workflow: [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)

Required GitHub **Variables** (not Secrets / not passwords): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TF_STATE_RESOURCE_GROUP`, `TF_STATE_STORAGE_ACCOUNT`, `TF_STATE_CONTAINER`, `TF_STATE_KEY`  
Optional Variables: `TF_VAR_location`, `TF_VAR_resource_group_name`, `TF_VAR_cluster_name`, `TF_VAR_node_count`, `TF_VAR_node_vm_size`

Auth is **OIDC** only — never add `AZURE_CLIENT_SECRET` or `AZURE_CREDENTIALS` to GitHub. See [docs/GITHUB-OIDC.md](docs/GITHUB-OIDC.md).

Never commit `terraform.tfvars`, `backend.hcl`, or `*.tfstate`.

---

## Tear down

```powershell
terraform destroy
# Optionally delete rg-tfstate after you no longer need the state blob
```

---

## Files

| File | Role |
|------|------|
| `versions.tf` / `providers.tf` | Toolchain + Azure auth |
| `network.tf` / `aks.tf` / `acr.tf` | RG, VNet, AKS, ACR |
| `backend.tf` | Remote state backend (partial) |
| `scripts/bootstrap-state.*` | Create state storage once |
| `.github/workflows/terraform.yml` | Plan / apply pipeline |
