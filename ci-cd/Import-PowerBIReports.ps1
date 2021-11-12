[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $TenantId,

    [Parameter()]
    [string]
    $ClientId,

    [Parameter()]
    [string]
    $ClientSecret,

    [Parameter()]
    [string]
    $WorkspaceName,

    [Parameter()]
    [string]
    $PbixFolderPath
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

$powerBiCredentials = New-Object System.Management.Automation.PSCredential $ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)

$account = Connect-PowerBIServiceAccount -Tenant $TenantId -Credential $powerBiCredentials -ServicePrincipal


echo "Authenticated as $($account.UserName) within tenant $($account.TenantId) (env = $($account.Environment))"


echo "Get workspace $WorkspaceName"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName

if(!$workspace) {
    echo "Creating new workspace $WorkspaceName"
    $workspace = New-PowerBIWorkspace -Name $WorkspaceName
}

$reportFilePaths = gci $PbixFolderPath -Filter *.pbi* -File | Select FullName
$failedReportFilePaths = @()
foreach($reportFilePath in $reportFilePaths) {
    try {
        echo "Uploading report $($reportFilePath.FullName)"
        New-PowerBIReport -Path $reportFilePath.FullName -WorkspaceId $workspace.Id -ConflictAction CreateOrOverwrite -ErrorAction Stop
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