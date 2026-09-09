# Bootstrap: free GitHub repos + first deploy

**You do not need a paid GitHub plan.** A free GitHub account is enough for this learning lab:

| Feature | Free account |
|---------|----------------|
| Private or public repos | Yes |
| GitHub Actions (CI/CD) | Yes (public: generous; private: free monthly minutes) |
| Secrets / Variables | Yes |

Create an account at: https://github.com/signup  

This lab uses **GitHub** (not GitLab/Bitbucket) because the workflows are written for **GitHub Actions**.

End-to-end order:

```text
GitHub signup  →  bootstrap-state  →  push aks-infra  →  set sample-app vars  →  push sample-app
```

---

## 0. Tools

- Free [GitHub](https://github.com/signup) account
- [Git](https://git-scm.com/downloads) (you already have this if `git --version` works)
- Azure CLI (`az login`)
- Terraform `>= 1.5`
- Optional: [GitHub CLI](https://cli.github.com/) — not required; browser steps below work fine

---

## 1. Create two **empty** repos in the browser (free)

1. Sign in → https://github.com/new  
2. Repository name: **`aks-infra`**  
   - Visibility: **Private** (or Public — both free)  
   - Do **not** add README, `.gitignore`, or license (keep it empty)  
   - Create repository  
3. Repeat for **`sample-app`** (also empty)

Copy your username from the URL, e.g. `https://github.com/YOUR_USER/aks-infra` → `YOUR_USER`.

---

## 2. Bootstrap remote Terraform state (once)

From `aks-cluster/`:

```powershell
az login
az account set --subscription "<your-subscription-id>"
.\scripts\bootstrap-state.ps1
# WSL/Linux: bash scripts/bootstrap-state.sh
```

Save the printed `TF_STATE_*` values for GitHub Variables.

Optional local init:

```powershell
copy terraform.tfvars.example terraform.tfvars
# edit subscription_id / location / names
terraform init -backend-config=backend.hcl
```

If you previously used **local** state:

```powershell
terraform init -migrate-state -backend-config=backend.hcl
```

---

## 3. Push local folders to the free GitHub repos

Use a [Personal Access Token](https://github.com/settings/tokens) (classic: `repo` scope) or GitHub Desktop if HTTPS asks for a password. GitHub no longer accepts account passwords for `git push`.

```powershell
# --- aks-infra ---
cd c:\SunilTechnical\Terraform&K8\aks-cluster
git init -b main
git add .
git status
# Must NOT list: terraform.tfvars, backend.hcl, *.tfstate
git commit -m "Initial aks-infra: AKS, ACR, Terraform CI/CD"
git remote add origin https://github.com/YOUR_USER/aks-infra.git
git push -u origin main

# --- sample-app ---
cd c:\SunilTechnical\Terraform&K8\sample-app
git init -b main
git add .
git commit -m "Initial sample-app: Node app + AKS deploy workflow"
git remote add origin https://github.com/YOUR_USER/sample-app.git
git push -u origin main
```

Replace `YOUR_USER` with your GitHub username.

Optional (if you install `gh` later):

```powershell
winget install --id GitHub.cli
gh auth login
# then: gh repo create … as in older docs
```

---

## 4. Configure OIDC + variables (no Azure passwords on GitHub)

Follow [GITHUB-OIDC.md](GITHUB-OIDC.md):

1. App registration — **do not create a client secret**
2. Federated credentials for `sunilkrdeep/aks-infra` and `sunilkrdeep/sample-app`
3. Put `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` in **Variables** (GUIDs only)
4. `TF_STATE_*` on **aks-infra**

Never add `AZURE_CLIENT_SECRET` or `AZURE_CREDENTIALS` JSON to GitHub.

---

## 5. Run infrastructure pipeline first

Opening **Actions** on `aks-infra` after the first push should show the **Terraform** workflow. First apply takes **~8–15 minutes**.

When it succeeds, read ACR / AKS names from the job log (**Print useful outputs**) or from local Terraform:

```powershell
terraform output -raw acr_name
terraform output -raw resource_group_name
terraform output -raw cluster_name
```

Then add those three as **Variables** on `sample-app`.

Re-run **Deploy to AKS** on `sample-app` (Actions → workflow → Run workflow), or push a small commit.

---

## 6. Verify on AKS

```powershell
az aks get-credentials -g <AKS_RESOURCE_GROUP> -n <AKS_CLUSTER_NAME> --overwrite-existing
kubectl get nodes
kubectl get pods,svc -l app=sample-app -o wide
```

Open `http://<EXTERNAL-IP>/` when the LoadBalancer has an IP.

---

## Day-2 loop

| Change | Repo | Result |
|--------|------|--------|
| Node count, VM size, network | `aks-infra` PR → merge | Terraform plan then apply |
| App text / code | `sample-app` push to `main` | New image + rolling deploy |

---

## Tear down

1. Optional: `kubectl delete -f k8s/` in sample-app  
2. `terraform destroy` in aks-infra (with backend configured)  
3. Delete Azure RG `rg-tfstate` when you no longer need state  
4. Delete or archive the two GitHub repos (Settings → Delete) when finished learning  
