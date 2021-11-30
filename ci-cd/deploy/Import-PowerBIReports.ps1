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
    [string]$PbixFolderPath
)

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

function Update-ReportContent{
    param ($reportFilePath, $stagingWorkspaceName, $targetWorkspaceId, $targetReportId)

    echo "Get workspace $stagingWorkspaceName"
    $stagingWorkspace = Get-PowerBIWorkspace -Name $stagingWorkspaceName
    
    if(!$stagingWorkspace) {
        echo "Creating new workspace $stagingWorkspaceName"
        $stagingWorkspace = New-PowerBIWorkspace -Name $stagingWorkspaceName
    }
    echo "Uploading report $($reportFilePath.FullName) to $stagingWorkspaceName"
    $stagingReport = New-PowerBIReport -Path $reportFilePath.FullName -WorkspaceId $stagingWorkspace.Id -ConflictAction CreateOrOverwrite -ErrorAction Stop

    $baseUri = "https://api.powerbi.com/v1.0/myorg"

    $body = @{ 
        sourceReport = 
            @{
                sourceReportId="$($stagingReport.Id)"
                sourceWorkspaceId="$($stagingWorkspace.Id)"
            }
        sourceType = "ExistingReport"
    } | ConvertTo-Json

    echo 'Copy report content from staging to target'
    $updateReportUri = "$baseUri/groups/$targetWorkspaceId/reports/$targetReportId/UpdateReportContent"
    echo $updateReportUri
    Invoke-PowerBIRestMethod -Method Post -Url $updateReportUri -Body $body -ContentType 'application/json' -Verbose;

    echo 'Remove the staging report'
    Remove-PowerBIReport -Id $stagingReport.Id -WorkspaceId $stagingWorkspace.Id;
}

$powerBiCredentials = New-Object System.Management.Automation.PSCredential $ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)

$account = Connect-PowerBIServiceAccount -Tenant $TenantId -Credential $powerBiCredentials -ServicePrincipal

echo "Get workspace $WorkspaceName"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName

$reportFilePaths = gci $PbixFolderPath -Filter *.pbi* -File | Select FullName, BaseName
$failedReportFilePaths = @()
foreach($reportFilePath in $reportFilePaths) {
    try {
        echo "Looking up report $($reportFilePath.BaseName)"
        $report = Get-PowerBIReport -workspace $workspace -Name $reportFilePath.BaseName

        if ($report) {
            echo "Uploading updated report $($reportFilePath.FullName)"
            Update-ReportContent $reportFilePath 'DeploymentStaging' $workspace.Id $report.Id
        } else {
            echo "Uploading new report $($reportFilePath.FullName)"
            New-PowerBIReport -Path $reportFilePath.FullName -WorkspaceId $workspace.Id -ConflictAction CreateOrOverwrite -ErrorAction Stop
        }
    }
    catch {
        Resolve-PowerBIError -Last
        $failedReportFilePaths += $reportFilePath.FullName
    }
}

if ($failedReportFilePaths.Length -gt 0) {
    $failedReportFilePathsString = $failedReportFilePaths -join '`n'
    throw "The following pbix files failed to import: $failedReportFilePathsString"
}