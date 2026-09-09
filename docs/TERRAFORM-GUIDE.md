# Terraform from scratch — then this AKS lab

This guide is for someone who has **never used Terraform**. It first explains Terraform itself, then maps every idea onto the files in `aks-cluster/` that build an AKS cluster (Azure-managed control plane + 2 worker VMs).

---

## 1. What problem Terraform solves

Azure Portal clicks work once. They do not:

- live in Git
- show a preview of *exactly* what will change
- recreate the same cluster on another subscription
- tear everything down cleanly

**Terraform is Infrastructure as Code (IaC).** You write a desired end state in text files. Terraform talks to Azure and makes reality match that state.

Analogy:

| Concept | Everyday equivalent |
|---------|---------------------|
| `.tf` files | A shopping list written in a strict language |
| `terraform plan` | The cashier showing you the bill *before* you pay |
| `terraform apply` | Paying and walking out with the items |
| `terraform.tfstate` | The receipt — proof of what you already own |
| `terraform destroy` | Returning everything on the receipt |

You describe **what** you want (`2 worker nodes in eastus`). Terraform figures out **how** (create RG → VNet → subnet → AKS).

---

## 2. The Terraform language (HCL)

Files end in `.tf` and use **HCL** (HashiCorp Configuration Language). It looks like this:

```hcl
resource "azurerm_resource_group" "aks" {
  name     = "aks-sutramind-rg"
  location = "South India"
}
```

Read that as:

> Create an Azure resource of type `azurerm_resource_group`.  
> Call this instance `aks` (a local nickname used only inside Terraform).  
> Set `name` and `location`.

### Building blocks you will see everywhere

| Block | Purpose | Example in this lab |
|-------|---------|---------------------|
| `terraform {}` | Toolchain: CLI version + which providers to download | `versions.tf` |
| `provider "azurerm"` | How to log in to Azure | `providers.tf` |
| `variable "x"` | Input knob | `variables.tf` |
| `locals {}` | Computed constants | `locals.tf` |
| `resource "TYPE" "NAME"` | Something Terraform **creates** | `network.tf`, `aks.tf` |
| `data "TYPE" "NAME"` | Something Terraform **reads** (already exists) | not used here |
| `output "x"` | Value printed after apply | `outputs.tf` |

### Expressions

```hcl
name = "${var.cluster_name}-vnet"          # string interpolation
name = azurerm_resource_group.aks.name     # reference another resource
dns_prefix = local.dns_prefix              # reference a local
node_count = var.node_count                # reference a variable
```

Terraform builds a **dependency graph** from these references. The resource group is created first because the VNet uses `azurerm_resource_group.aks.location`. You almost never need `depends_on`.

### Types you will meet

- `string` — `"eastus"`
- `number` — `2`
- `bool` — `true`
- `list(string)` — `["10.10.0.0/16"]`
- `map(string)` — `{ project = "aks-lab" }`
- `null` — “omit this argument, use the cloud default”

---

## 3. Providers — Terraform does not know Azure by itself

Terraform core is a graph engine. **Providers** are plugins that know one API:

| Provider | Talks to |
|----------|----------|
| `hashicorp/azurerm` | Azure Resource Manager (this lab) |
| `hashicorp/kubernetes` | A Kubernetes API (your other folders: Kafka, Flink, Iceberg) |
| `hashicorp/helm` | Helm charts |
| `hashicorp/random` | Random strings (DNS uniqueness here) |

`terraform init` downloads providers listed in `versions.tf` into `.terraform/` and locks exact versions in `.terraform.lock.hcl`.

That is why this lab’s `versions.tf` is the first file to read: it answers “which cloud, which plugin version.”

---

## 4. State — the most important file you never edit by hand

After a successful apply, Terraform writes `terraform.tfstate`.

It stores:

- every resource ID Azure returned (`/subscriptions/…/resourceGroups/aks-sutramind-rg`)
- attributes you will reference later (cluster FQDN, kubeconfig)

On the **next** plan, Terraform does:

```text
  .tf files          = what you WANT
  terraform.tfstate  = what Terraform thinks EXISTS
  Azure API refresh  = what actually EXISTS right now
```

Then it computes: create / update / replace / destroy / no-op.

**Rules:**

- Never commit `*.tfstate` to Git (this folder’s `.gitignore` already excludes it). It can contain kubeconfig secrets.
- Never change Azure by hand *and* via Terraform for the same object (drift).
- For a team, state belongs in Azure Storage (remote backend). This lab uses **local state** so you can learn with one laptop.

---

## 5. The four commands (memorize these)

You always run them from the folder that contains the `.tf` files (`aks-cluster/`).

### `terraform init`

One-time (and again when you add a provider). Downloads `azurerm` + `random`. Safe to re-run.

### `terraform plan`

Read-only preview. Example output:

```text
Plan: 5 to add, 0 to change, 0 to destroy.
```

Symbols:

| Symbol | Meaning |
|--------|---------|
| `+` | will be created |
| `~` | will be updated in place |
| `-/+` | must be destroyed and recreated (replacement) |
| `-` | will be destroyed |

Always read the plan before apply. A replacement of `azurerm_kubernetes_cluster` means **the whole cluster is rebuilt**.

### `terraform apply`

Shows the same plan, asks `yes`, then calls Azure. First AKS apply takes ~8–15 minutes.

Useful flags:

```powershell
terraform apply -auto-approve          # skip the yes prompt (CI only)
terraform apply -var="node_count=3"    # override one variable for this run
```

### `terraform destroy`

Deletes **everything in state** for this folder. That is how you stop the Azure bill.

Other useful commands:

```powershell
terraform fmt          # auto-format .tf files
terraform validate     # syntax + type check (needs init first)
terraform output       # print outputs without applying
terraform state list   # list resources Terraform currently tracks
```

---

## 6. Variables vs locals vs hard-coded values

| Kind | Who changes it | Example |
|------|----------------|---------|
| Hard-coded in a resource | Nobody without editing `.tf` | bad for region / node count |
| `variable` | You, in `terraform.tfvars` | `node_count = 2` |
| `local` | Derived automatically | `dns_prefix = "aks-lab-a9k2"` |

Workflow:

1. Declare the knob in `variables.tf` (type, description, default, optional validation).
2. Set the real value in `terraform.tfvars` (gitignored — contains your subscription ID).
3. Reference it as `var.node_count`.

Copy the sample:

```powershell
copy terraform.tfvars.example terraform.tfvars
```

Priority (highest wins): `-var` on the CLI → `terraform.tfvars` → variable `default`.

---

## 7. How AKS actually works (critical)

You asked for “AKS using 2 VM worker nodes and AKS control plane / master node.”

In **AKS you do not create a master VM.** That is the difference between:

| Model | Control plane | Worker nodes |
|-------|---------------|--------------|
| **AKS (this lab)** | Azure hosts API server + etcd. Invisible in `kubectl get nodes`. Free SKU = no control-plane charge. | Your VMs. Here: **2**. |
| Self-managed (kubeadm on VMs) | You build 1+ master VMs yourself | Your VMs |

`kubectl get nodes` after apply will show **two** nodes, both `agentpool=system`. There is no third “master” row. The API server is a Microsoft-hosted endpoint; Terraform prints it as `cluster_fqdn`.

```text
You / kubectl
      │
      │  HTTPS to FQDN  (aks-lab-xxxx.hcp.eastus.azmk8s.io)
      ▼
Azure-managed control plane     ← not a VM in your subscription
      │
      │  AKS tunnel
      ▼
Your VNet  10.10.1.0/24
      ├── Worker VM 1  (kubelet + pods)
      └── Worker VM 2  (kubelet + pods)
```

The worker VMs live in an Azure-managed resource group named like `MC_rg-aks-lab_aks-lab_eastus`. Terraform output `node_resource_group` is that name. Treat it as read-only.

---

## 8. This folder, file by file

Terraform loads **every** `*.tf` in the directory as one module. Splitting files is only for humans. Order on disk does not matter; references do.

```text
aks-cluster/   (GitHub: aks-infra)
├── versions.tf                 toolchain
├── providers.tf                Azure login
├── backend.tf                  remote state (Azure Storage)
├── variables.tf                inputs
├── locals.tf                   derived names + random suffix
├── network.tf                  RG + VNet + subnet
├── aks.tf                      AKS cluster + Network Contributor role
├── acr.tf                      Container Registry + AcrPull
├── outputs.tf                  values printed after apply
├── terraform.tfvars.example    template for local secrets/IDs
├── backend.hcl.example         template for state backend
├── .github/workflows/          terraform plan / apply
├── scripts/bootstrap-state.*   one-time state storage
├── scripts/get-credentials.ps1 az aks get-credentials wrapper
└── scripts/verify.ps1          Azure + kubectl checks
```

### 8.1 `versions.tf`

Pins Terraform `>= 1.5.0` and providers:

- `hashicorp/azurerm ~> 4.0` — Azure resources
- `hashicorp/random ~> 3.6` — 4-character suffix so the AKS DNS name is unique in the region

`~>` means “allow patch/minor updates inside that major line” (4.0.0 → 4.99.x, not 5.x).

### 8.2 `providers.tf`

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

`azurerm` 4.x **requires** `subscription_id`. Terraform does not guess it from `az login` anymore.

How login works in practice:

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

The Azure CLI session is enough for the provider. No client secret is needed on your laptop.

### 8.3 `variables.tf`

Knobs with defaults that match a small lab:

| Variable | Default | Meaning |
|----------|---------|---------|
| `subscription_id` | *(required)* | Which Azure bill |
| `location` | `eastus` | Region (change to `centralindia` if you prefer) |
| `resource_group_name` | `rg-aks-lab` | Container for all lab resources |
| `cluster_name` | `aks-lab` | AKS name |
| `node_count` | `2` | Worker VMs |
| `node_vm_size` | `Standard_D2s_v3` | 2 vCPU / 8 GiB each (AKS system-pool minimum class) |
| `vnet_address_space` | `10.10.0.0/16` | VNet CIDR |
| `aks_subnet_prefix` | `10.10.1.0/24` | Where the 2 VMs get IPs |

Validation blocks reject a `cluster_name` that Azure would refuse (uppercase, too long).

### 8.4 `locals.tf`

- `random_string.suffix` — 4 alphanumeric characters
- `local.dns_prefix` — `aks-lab` + suffix → becomes part of the API FQDN
- `local.kubernetes_version` — empty string in tfvars becomes `null` so Azure picks the default version

### 8.5 `network.tf` — three resources

1. `azurerm_resource_group.aks` — empty folder in Azure
2. `azurerm_virtual_network.aks` — `10.10.0.0/16`
3. `azurerm_subnet.aks` — `10.10.1.0/24` named `snet-aks`

The subnet ID is passed into AKS so worker NICs land in *your* VNet, not a hidden one.

### 8.6 `aks.tf` — the cluster

`azurerm_kubernetes_cluster.aks` is one Terraform resource that creates many Azure objects:

| Argument | Effect |
|----------|--------|
| `sku_tier = "Free"` | No SLA, no control-plane fee |
| `default_node_pool.node_count = 2` | Two worker VMs |
| `vm_size` | Size of each worker |
| `vnet_subnet_id` | Place VMs in `snet-aks` |
| `identity { type = SystemAssigned }` | AKS gets an Azure AD identity to create load balancers / disks |
| `network_plugin_mode = overlay` | Pods use `10.244.0.0/16`; nodes use `10.10.1.0/24` |
| `oidc_issuer_enabled` | Needed later if you add Azure Workload Identity |

`azurerm_role_assignment.aks_network` grants that identity **Network Contributor** on the VNet. Without it, AKS cannot attach NICs or create the Standard Load Balancer in a bring-your-own-VNet design.

### 8.7 `acr.tf` — registry for sample-app CI

`azurerm_container_registry.acr` holds Docker images. `azurerm_role_assignment.aks_acr_pull` grants the AKS **kubelet** identity `AcrPull` so nodes can pull without registry passwords in the cluster.

### 8.8 `outputs.tf`

After apply you get copy-paste commands:

```powershell
terraform output get_credentials_command
terraform output -raw kube_config     # hidden by default (sensitive)
terraform output acr_name             # set as ACR_NAME on sample-app
```

---

## 9. End-to-end runbook

### One-time tooling

1. Install Terraform and Azure CLI.
2. `az login` and copy the subscription ID (`az account show --query id -o tsv`).
3. Install kubectl.

### Every new laptop / folder

```powershell
cd c:\SunilTechnical\Terraform&K8\aks-cluster
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars          # paste subscription_id, optional region
terraform init
terraform plan
terraform apply                   # type yes
```

### After apply

```powershell
.\scripts\get-credentials.ps1
kubectl get nodes -o wide
```

Expected: 2 nodes, `Ready`, VM size matching `node_vm_size`.

Run a test pod:

```powershell
kubectl run nginx --image=nginx --port=80
kubectl get pods -o wide
```

The pod schedules onto one of the two worker VMs.

### Scale workers to 3 without rebuilding the control plane

In `terraform.tfvars`:

```hcl
node_count = 3
```

Then:

```powershell
terraform plan    # should show ~ default_node_pool.node_count: 2 → 3
terraform apply
```

AKS adds a third VM in the scale set. The API server stays up.

### Delete the lab

```powershell
terraform destroy
```

Confirm the resource group is gone in Azure Portal. If destroy fails halfway, run it again; Terraform continues from state.

---

## 10. How Terraform decides the order of creates

From the references in this lab:

```text
random_string.suffix
        │
        ▼
azurerm_resource_group.aks
        │
        ├──────────────► azurerm_virtual_network.aks
        │                         │
        │                         ▼
        │               azurerm_subnet.aks
        │                         │
        ▼                         ▼
azurerm_kubernetes_cluster.aks ◄──┘
        │
        ├──► azurerm_role_assignment.aks_network
        │
        ├──► azurerm_container_registry.acr
        │              │
        └──────────────┴──► azurerm_role_assignment.aks_acr_pull
```

You did not write that graph. Terraform inferred it because each resource interpolates attributes of the previous one.

---

## 11. Cost and safety notes

- **Workers** (`Standard_D2s_v3` × 2) are the main cost, plus a Standard SKU load balancer and managed disks.
- **Control plane** on `sku_tier = "Free"` is not billed.
- Do not leave the cluster running overnight if this is only a learning subscription.
- `terraform destroy` is the cleanup. Deleting the resource group in Portal while Terraform still has state will confuse the next plan (resources already gone).

Cheaper learning size (if the region supports it for AKS system pools):

```hcl
node_vm_size = "Standard_B2s"
```

If Azure rejects `B2s` for a system pool, keep `Standard_D2s_v3`.

---

## 12. Common errors (and what they mean)

| Error | Cause | Fix |
|-------|--------|-----|
| `subscription_id must be specified` | `terraform.tfvars` still has the placeholder or is missing | Set a real GUID from `az account show` |
| `Error: obtaining token` | Not logged in | `az login` |
| `QuotaExceeded` / SKU not available | Region out of `D2s_v3` | Change `location` or `node_vm_size` |
| `dns_prefix` already used | Rare collision | Re-apply; `random_string` is in state so it stays stable; destroy + new apply if you need a new prefix |
| `kubectl` “connection refused” / unauthorized | Kubeconfig not downloaded | `.\scripts\get-credentials.ps1` |
| Plan wants to **replace** the whole AKS cluster | You changed a ForceNew field (name, region, network plugin, …) | Read the plan; that rebuilds everything |

---

## 13. How this differs from your other folders

| Folder | Provider | Target |
|--------|----------|--------|
| `Iceberg-Spark`, `Apache_Kafka_FlinkSQL_sql_Gateway`, … | `hashicorp/kubernetes` | Objects **inside** an existing cluster (Rancher Desktop) |
| **`aks-cluster` / GitHub `aks-infra`** | `hashicorp/azurerm` | The **cluster itself** + ACR in Azure |
| **`sample-app`** | GitHub Actions + kubectl | App image onto that AKS cluster |

Typical real workflow:

1. GitHub Actions on `aks-infra` applies Terraform (AKS + ACR).
2. GitHub Actions on `sample-app` builds, pushes to ACR, deploys with kubectl.
3. Optional: your Kafka / Flink Terraform (kubernetes provider) can later target the same AKS kubeconfig.

That is two layers: **cloud** Terraform, then **app** CI/CD (and optionally **cluster** Terraform for workloads).

---

## 14. Mental model to keep

```text
You edit .tf / .tfvars
        │
        ▼
terraform plan     →  “here is the diff vs Azure”
        │
        ▼
terraform apply    →  Azure APIs run
        │
        ▼
terraform.tfstate  →  IDs saved
        │
        ▼
kubectl            →  you use the cluster (not Terraform) until the next infra change
```

Terraform is not a replacement for kubectl. It builds the house (AKS + 2 VMs). kubectl furnishes the rooms (pods, services).
