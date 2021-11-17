[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$ClientId,

    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName
)

If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Profile -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Profile -Force -Verbose -Scope CurrentUser
}
If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Workspaces -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Workspaces -Force -Verbose -Scope CurrentUser
}

$powerBiCredentials = New-Object System.Management.Automation.PSCredential $ClientId, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)

$account = Connect-PowerBIServiceAccount -Tenant $TenantId -Credential $powerBiCredentials -ServicePrincipal

echo "Get workspace $WorkspaceName"
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName

if(!$workspace) {
    echo "Creating new workspace $WorkspaceName"
    $workspace = New-PowerBIWorkspace -Name $WorkspaceName
    throw "Workspace `"$WorkspaceName`" must be added to Premium capacity plan to continue deployment"
}

# NOTE: SPNs cannot currently add a workspace to a capacity

# $ErrorActionPreference = 'Stop'

# az login --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
# #az login

# $resource = 'https://analysis.windows.net/powerbi/api'
# $token = az account get-access-token --resource $resource | ConvertFrom-Json

# $authToken = $token.accessToken
# $headers = @{"Authorization"="Bearer $authToken"}

# $baseUri = "https://api.powerbi.com/v1.0/myorg"

# echo "Get capacities"
# $capacities = Invoke-RestMethod -Method GET -Uri  "$baseUri/capacities" `
#     -Headers $headers

# $capacity = $capacities.value | ? displayName -like 'Premium Per User*'

# echo "Add $WorkspaceName to $($capacity.displayName) capacity plan"
# $body = @{ 
#     "targetCapacityObjectId" = $capacity.Id
#     "workspacesToAssign" = @($workspace.Id)
# } | ConvertTo-Json -Compress

# Invoke-RestMethod -Method POST -Uri "$baseUri/admin/capacities/AssignWorkspaces" `
#     -Headers $headers `
#     -Body $body -ContentType 'application/json' -Verbose