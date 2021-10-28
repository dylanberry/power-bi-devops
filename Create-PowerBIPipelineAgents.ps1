$ansible_control_node_ip = (Invoke-WebRequest http://ipecho.net/plain).Content
$management_ip = (Invoke-WebRequest http://ipecho.net/plain).Content

pushd terraform

terraform apply `
    -var="location=eastus" `
    -var="resource_group=PowerBIDevOps" `
    -var="ansible_control_node_ip=$ansible_control_node_ip" `
    -var="domain_name_prefix=pbidevops" `
    -var="management_ip=$management_ip" `
    -auto-approve

$tfOutput = terraform output -json | ConvertFrom-Json

popd

pushd ansible

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
AzdoAccount=$(System.TeamFoundationCollectionUri)
AzdoPat=$($env:AZURE_DEVOPS_EXT_PAT)
WindowsLogonAccount=$($tfOutput.vmUserName.value)
WindowsLogonPassword=$($tfOutput.vmPassword.value)
WorkDirectory=''"

ansible-playbook -i hosts ./power_bi_devops_windows_tools.yml `
    --extra-vars $playbookVars

popd