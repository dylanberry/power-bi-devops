[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AzdoUri,

    [Parameter (Mandatory= $true)]
    [String] $Location,

    [Parameter (Mandatory= $true)]
    [String] $BackendResourceGroupName,
  
    [Parameter (Mandatory= $true)]
    [String] $BackendStorageAccountName,
  
    [Parameter (Mandatory= $true)]
    [String] $BackendStorageContainerName,

    [Parameter(Mandatory=$true)]
    [string]$VmResourceGroupName
)

$ansibleControlNodeIP = (Invoke-WebRequest http://ipecho.net/plain).Content
$managementIP = (Invoke-WebRequest http://ipecho.net/plain).Content


# Ensure backend storage account
az group create --name $BackendResourceGroupName --location $Location
az storage account create --name $BackendStorageAccountName.ToLower() --resource-group $BackendResourceGroupName --location $Location --sku 'Standard_LRS'

$storageAccountKeys = az storage account keys list --resource-group $BackendResourceGroupName --account-name $BackendStorageAccountName.ToLower() | ConvertFrom-Json
$storageAccountKey = $storageAccountKeys[0].value

az storage container create --name $backendStorageContainerName.ToLower()  --account-name $BackendStorageAccountName.ToLower() --account-key $storageAccountKey


# Set terraform AzureRM provider credentials from service connection
$env:ARM_SUBSCRIPTION_ID = (az account show | ConvertFrom-Json).id
$env:ARM_CLIENT_ID = $env:servicePrincipalId
$env:ARM_CLIENT_SECRET = $env:servicePrincipalKey
$env:ARM_TENANT_ID = $env:tenantId


try {
    pushd terraform
    
    terraform init `
        -backend-config="resource_group_name=$BackendResourceGroupName" `
        -backend-config="storage_account_name=$($BackendStorageAccountName.ToLower())" `
        -backend-config="container_name=$($BackendStorageContainerName.ToLower())" `
        -backend-config="key=$backendStateFileName" `
        -backend-config="access_key=$storageAccountKey"
    
    terraform apply `
        -var="location=$Location" `
        -var="resource_group=$VmResourceGroupName" `
        -var="ansible_control_node_ip=$ansibleControlNodeIP" `
        -var="domain_name_prefix=pbidevops" `
        -var="management_ip=$managementIP" `
        -auto-approve
    
    $tfOutput = terraform output -json | ConvertFrom-Json
}
finally {
    popd
}


try {
    pushd ansible

    pip install ansible

    echo 'Generate ansible inventory from Terraform output'

    $hosts = "[azurevms]
    $($tfOutput.vmIps.value -join ""`n"")

    [azurevms:vars]
    ansible_user=$($tfOutput.vmUserName.value)
    ansible_password=$($tfOutput.vmPassword.value)
    ansible_connection=winrm
    ansible_winrm_transport=basic
    ansible_winrm_server_cert_validation=ignore
    ansible_port=$($tfOutput.vmAnsiblePort.value)"

    $hosts | Out-File 'hosts'

    echo 'Run ansible playbook'

    $playbookVars = "PoolName=Default
    AzdoUri=$AzdoUri
    AzdoPat=$($env:AZURE_DEVOPS_EXT_PAT)
    WindowsLogonAccount=$($tfOutput.vmUserName.value)
    WindowsLogonPassword=$($tfOutput.vmPassword.value)
    WorkDirectory=''"

    ansible-playbook -i hosts ./power_bi_devops_windows_tools.yml `
        --extra-vars $playbookVars
}
finally {
    popd
}
