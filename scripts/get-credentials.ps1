# Merge AKS kubeconfig into %USERPROFILE%\.kube\config
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$rg      = terraform output -raw resource_group_name
$cluster = terraform output -raw cluster_name

Write-Host "Downloading credentials for cluster '$cluster' in '$rg'..."
az aks get-credentials --resource-group $rg --name $cluster --overwrite-existing
kubectl get nodes -o wide
