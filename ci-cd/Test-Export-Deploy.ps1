$clientId = $env:clientId
$clientSecret = $env:clientSecret
$tenantId = $env:tenantId

$sourceWorkspaceName = "DevOps"
$targetWorkspaceName = "UAT"

$workDirectory = 'C:\w'
$toolsFolderPath = "$workDirectory/t"
$sourcesDirectory = "$workDirectory/s"
$buildDirectory = "$workDirectory/b"
$artifactStagingDirectory = "$workDirectory/a"

$exportedPbixFolderPath = "$buildDirectory/pbix"
$compiledPbixFolderPath = "$artifactStagingDirectory/pbix"
$reportSourceFolderPath = "$sourcesDirectory/src/reports"
$bimFolderPath = "$sourcesDirectory/src/datasets"

$pbiToolsPath = "$toolsFolderPath/pbi-tools"

$ErrorActionPreference = 'Stop'

New-Item -ItemType "directory" -Path $workDirectory -Force
cd $workDirectory


echo "Download and Install PBI Tools"
$params = @{
    PbiToolsPath = $pbiToolsPath 
}
&"$PSScriptRoot/util/Install-PbiTools.ps1" @params


echo "Export reports from $sourceWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $sourceWorkspaceName
    PbixFolderPath = $exportedPbixFolderPath
}
&"$PSScriptRoot/export/Export-PowerBIReports.ps1" @params


echo "Extract PBIX Files"
$params = @{
    PbiToolsPath = $pbiToolsPath
    ReportSourceFolderPath = $reportSourceFolderPath
    PbixFolderPath = $exportedPbixFolderPath
}
&"$PSScriptRoot/export/Extract-PowerBIReports.ps1" @params


echo "Export datasets from $sourceWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    ToolsFolderPath = $toolsFolderPath
    WorkspaceName = $sourceWorkspaceName
    BimFolderPath = $bimFolderPath
}
&"$PSScriptRoot/export/Export-PowerBIDataset.ps1" @params


echo "Ensure $targetWorkspaceName workspace created"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
}
&"$PSScriptRoot/deploy/Ensure-PowerBIWorkspace.ps1" @params


echo "Import datasets to $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
    BimFolderPath = $bimFolderPath
}
powershell -version 5.1 "$PSScriptRoot/deploy/Import-PowerBIDatasets.ps1" @params


echo "Compile PBIX Files"
$params = @{
    PbiToolsPath = $pbiToolsPath
    ReportSourceFolderPath = $reportSourceFolderPath
    PbixFolderPath = $compiledPbixFolderPath
}
&"$PSScriptRoot/deploy/Compile-PowerBIReports.ps1" @params


echo "Import reports to $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
    PbixFolderPath = $compiledPbixFolderPath
}
&"$PSScriptRoot/deploy/Import-PowerBIReports.ps1" @params


echo "Rebind report datasets and update credentials in $targetWorkspaceName"
$params = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantId = $tenantId
    WorkspaceName = $targetWorkspaceName
}
&"$PSScriptRoot/deploy/Update-ReportDatasets.ps1" @params