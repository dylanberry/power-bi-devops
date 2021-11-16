$clientId = $env:clientId
$clientSecret = $env:clientSecret
$tenantId = $env:tenantId

$sourceWorkspaceName = "DevOps"
$targetWorkspaceName = "UAT"

$pbixFolderPath = './pbix'
$bimFolderPath = './bim'

pushd $PSScriptRoot

echo "Export reports from $sourceWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $sourceWorkspaceName
    PbixFolderPath = $pbixFolderPath
}
./export/Export-PowerBIReports.ps1 @params

echo "Export datasets from $sourceWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $sourceWorkspaceName
    BimFolderPath = $bimFolderPath
}
./export/Export-PowerBIDataset.ps1 @params

echo "Import reports to $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
    BimFolderPath = $bimFolderPath
}
./import/Import-PowerBIDataset.ps1 @params

echo "Import reports to $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
    PbixFolderPath = $pbixFolderPath
}
./import/Import-PowerBIReports.ps1 @params

echo "Rebind report datasets and update credentials in $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
}
./import/Update-ReportDatasets.ps1 @params