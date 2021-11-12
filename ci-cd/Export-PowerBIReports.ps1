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


echo "Get all reports from $WorkspaceName"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName
$reports = Get-PowerBIReport -WorkspaceId $workspace.Id

New-Item -ItemType "directory" -Path $PbixFolderPath -Force

$failedReportFilePaths = @()
foreach ($report in $reports) {
    try {
        $fileName = "$PbixFolderPath\$($report.Name).pbix"
        echo "Export report id $($report.Id) to $fileName"
        Export-PowerBIReport -WorkspaceId $workspace.Id -Id $report.Id -OutFile $fileName
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