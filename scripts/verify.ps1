# Post-apply checks: Azure resources + Kubernetes nodes
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$rg      = terraform output -raw resource_group_name
$cluster = terraform output -raw cluster_name

Write-Host "=== Azure: AKS cluster ==="
az aks show --resource-group $rg --name $cluster --query "{name:name, powerState:powerState.code, version:kubernetesVersion, nodeRg:nodeResourceGroup, fqdn:fqdn}" -o table

Write-Host "`n=== Azure: worker VMs (node resource group) ==="
$nodeRg = terraform output -raw node_resource_group
az vm list --resource-group $nodeRg --query "[].{name:name, size:hardwareProfile.vmSize, state:provisioningState}" -o table

Write-Host "`n=== Kubernetes nodes ==="
kubectl get nodes -o wide

Write-Host "`n=== Kubernetes system pods ==="
kubectl get pods -n kube-system
