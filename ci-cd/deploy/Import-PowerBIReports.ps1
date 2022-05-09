[CmdletBinding()]
param (

    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$ClientId,

    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [string]$PbixFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$DatasetName,

    [Parameter()]
    [string[]]$ReportList
)

$ErrorActionPreference = 'Stop'

#Install Modules
If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Profile -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Profile -Force -Verbose -Scope CurrentUser
}
If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Workspaces -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Workspaces -Force -Verbose -Scope CurrentUser
}
If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Reports -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Reports -Force -Verbose -Scope CurrentUser
}

#Constants
$baseUri = "https://api.powerbi.com/v1.0/myorg"

function Update-ReportContent{
    param ($reportFilePath, $stagingWorkspaceName, $targetWorkspaceId, $targetReportId)

    echo "Get workspace $stagingWorkspaceName"
    $stagingWorkspace = Get-PowerBIWorkspace -Name $stagingWorkspaceName
    
    if(!$stagingWorkspace) {
        echo "Creating new workspace $stagingWorkspaceName"
        $stagingWorkspace = New-PowerBIWorkspace -Name $stagingWorkspaceName
    }
    echo "Uploading report $reportFilePath to $stagingWorkspaceName"
    $stagingReport = New-PowerBIReport -Path $reportFilePath -WorkspaceId $stagingWorkspace.Id -ConflictAction CreateOrOverwrite -ErrorAction Stop

    
    $body = @{ 
        sourceReport = 
            @{
                sourceReportId="$($stagingReport.Id)"
                sourceWorkspaceId="$($stagingWorkspace.Id)"
            }
        sourceType = "ExistingReport"
    } | ConvertTo-Json



    Write-Host 'Copy report content from staging to target'
    $updateReportUri = "$baseUri/groups/$targetWorkspaceId/reports/$targetReportId/UpdateReportContent"
    
    Invoke-PowerBIRestMethod -Method Post -Url $updateReportUri -Body $body -ContentType 'application/json' -Verbose;
    #Invoke-RestMethod -Method Post -Uri $updateReportUri -Body $body -Headers $headers -ContentType 'application/json' -Verbose;
    Write-Host  'Remove the staging report'
    Remove-PowerBIReport -Id $stagingReport.Id -WorkspaceId $stagingWorkspace.Id;
}

$powerBiCredentials = New-Object System.Management.Automation.PSCredential $ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)

$account = Connect-PowerBIServiceAccount -Tenant $TenantId -Credential $powerBiCredentials -ServicePrincipal

echo "Get workspace $WorkspaceName"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName
try {
    $ReportList = $ReportList | ConvertFrom-Json
    Write-Host "Report List:"
    Write-Host $ReportList
  }
  catch {
    Write-Host "Report List is Empty"
  }

#Get the dataset to filter the reports
Write-Host "Get workspace $WorkspaceName"

$groupFilter = "name eq '$WorkspaceName'"
$groups = Invoke-PowerBIRestMethod -Method GET -Url "$baseUri/groups?`$filter=$groupFilter" | ConvertFrom-Json

Write-Host "Groups:"
Write-Host ($groups | Format-List | Out-String)


$groupId = $groups.value[0].id

$datasets = Invoke-PowerBIRestMethod -Method GET -Url "$baseUri/groups/$groupId/datasets" | ConvertFrom-Json
$dataset = $datasets.value | ? name -eq $DatasetName


$failedReportFilePaths = @()
foreach($reportName in $ReportList) {
    try {
        $reportFilePath = Join-Path $PbixFolderPath -ChildPath "$reportName.pbix"
        echo "Looking up report $reportFilePath"
        $report = Get-PowerBIReport -workspace $workspace -Name $reportName | Where-Object {$_.datasetId -eq $dataset.id} 

        if ($report) {
            echo "Uploading updated report $reportFilePath"
            Update-ReportContent $reportFilePath 'DeploymentStaging' $workspace.Id $report.Id
        } else {
            echo "Uploading new report $reportFilePath"
            New-PowerBIReport -Path $reportFilePath -WorkspaceId $workspace.Id -ConflictAction CreateOrOverwrite -ErrorAction Stop
        }
    }
    catch {
        Resolve-PowerBIError -Last
        $failedReportFilePaths += $reportFilePath
    }
}

if ($failedReportFilePaths.Length -gt 0) {
    $failedReportFilePathsString = $failedReportFilePaths -join '`n'
    throw "The following pbix files failed to import: $failedReportFilePathsString"
}