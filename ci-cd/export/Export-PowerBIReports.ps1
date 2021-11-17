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

$powerBiCredentials = New-Object System.Management.Automation.PSCredential $ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)

$account = Connect-PowerBIServiceAccount -Tenant $TenantId -Credential $powerBiCredentials -ServicePrincipal


echo "Authenticated as $($account.UserName) within tenant $($account.TenantId) (env = $($account.Environment))"


echo "Get reports from $WorkspaceName where name does not contain dataset"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName
$reports = Get-PowerBIReport -WorkspaceId $workspace.Id | ? Name -notlike "*Dataset*"

New-Item -ItemType "directory" -Path $PbixFolderPath -Force

$failedReportFilePaths = @()
foreach ($report in $reports) {
    try {
        $fileName = "$PbixFolderPath\$($report.Name).pbix"
        Remove-Item $fileName -ErrorAction SilentlyContinue
        echo "Export report id $($report.Id) to $fileName"
        Export-PowerBIReport -WorkspaceId $workspace.Id -Id $report.Id -OutFile $fileName
    }
    catch {
        Resolve-PowerBIError -Last
        $failedList += $report.Name
    }
}

if ($failedList.Length -gt 0) {
    $failedString = $failedList -join '`n'
    throw "The following reports failed to export: $failedString"
}