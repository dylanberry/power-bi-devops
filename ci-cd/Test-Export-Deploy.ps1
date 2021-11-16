$clientId = $env:clientId
$clientSecret = $env:clientSecret
$tenantId = $env:tenantId

$sourceWorkspaceName = "DevOps"
$targetWorkspaceName = "UAT"

$pbixFolderPath = './pbix'
$bimFolderPath = './bim'

pushd $PSScriptRoot

# echo "Export reports from $sourceWorkspaceName"
# $params = @{
#     ClientId = $clientId
#     ClientSecret = $clientSecret
#     TenantId = $tenantId
#     WorkspaceName = $sourceWorkspaceName
#     PbixFolderPath = $pbixFolderPath
# }
# ./export/Export-PowerBIReports.ps1 @params

# echo "Export datasets from $sourceWorkspaceName"
# $params = @{
#     ClientId = $clientId
#     ClientSecret = $clientSecret
#     TenantId = $tenantId
#     WorkspaceName = $sourceWorkspaceName
#     BimFolderPath = $bimFolderPath
# }
# ./export/Export-PowerBIDataset.ps1 @params

echo "Ensure $targetWorkspaceName workspace created"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
}
./deploy/Ensure-PowerBIWorkspace.ps1 @params

# echo "Import datasets to $targetWorkspaceName"
# $params = @{
#     ClientId = $clientId
#     ClientSecret = $clientSecret
#     TenantId = $tenantId
#     WorkspaceName = $targetWorkspaceName
#     BimFolderPath = $bimFolderPath
# }
# powershell -version 5.1 ./deploy/Import-PowerBIDatasets.ps1 @params

# echo "Import reports to $targetWorkspaceName"
# $params = @{
#     ClientId = $clientId
#     ClientSecret = $clientSecret
#     TenantId = $tenantId
#     WorkspaceName = $targetWorkspaceName
#     PbixFolderPath = $pbixFolderPath
# }
# ./deploy/Import-PowerBIReports.ps1 @params

# echo "Rebind report datasets and update credentials in $targetWorkspaceName"
# $params = @{
#     ClientId = $clientId
#     ClientSecret = $clientSecret
#     TenantId = $tenantId
#     WorkspaceName = $targetWorkspaceName
# }
# ./deploy/Update-ReportDatasets.ps1 @params