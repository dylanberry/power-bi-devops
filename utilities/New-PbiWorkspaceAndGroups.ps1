[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$EnvironmentName
)

$workspaceName = "$AppName ($EnvironmentName)"

az login

echo "Create Azure Active Directory group for each workspace role"
$pbiWorkspaceRoles = @( 'Admin', 'Contributor', 'Member', 'Viewer')

$pbiWorkspaceRoleGroups = @{}
foreach ($pbiRole in $pbiWorkspaceRoles){ 
    $aadGroupName = "PBI-WS-$($AppName.Replace(' ', ''))-$EnvironmentName-$pbiRole"
    $result = az ad group create --display-name $aadGroupName --mail-nickname $aadGroupName | ConvertFrom-Json
    $pbiWorkspaceRoleGroups[$pbiRole] = $result
}


If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Profile -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Profile -Force -Verbose -Scope CurrentUser
}
If(-not(Get-InstalledModule MicrosoftPowerBIMgmt.Workspaces -ErrorAction silentlycontinue)) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module MicrosoftPowerBIMgmt.Workspaces -Force -Verbose -Scope CurrentUser
}

Connect-PowerBIServiceAccount

echo "Get workspace $workspaceName"
$workspace = Get-PowerBIWorkspace -Name $workspaceName

if(!$workspace) {
    echo "Creating new workspace $workspaceName"
    $workspace = New-PowerBIWorkspace -Name $workspaceName
}

# Assign premium capacity to the workspace
echo "Get capacities"
$capacities = Invoke-PowerBIRestMethod -Method GET -Url "capacities" | ConvertFrom-Json

$capacity = $capacities.value | ? displayName -like 'Premium Per User*'

echo "Add $workspaceName ($($workspace.Id)) to $($capacity.displayName) ($($capacity.Id)) capacity plan"
$body = @{ 
    capacityMigrationAssignments =  @(@{
        targetCapacityObjectId = $capacity.Id;
        workspacesToAssign = @($workspace.Id)
    })
} | ConvertTo-Json -Depth 100
Invoke-PowerBIRestMethod -Method Post -Url "admin/capacities/AssignWorkspaces" -Body $body -Verbose

foreach($pbiRole in $pbiWorkspaceRoleGroups.Keys) {
    $aadGroup = $pbiWorkspaceRoleGroups[$pbiRole]

    echo "Assign $($aadGroup.displayName) to $workspaceName as $pbiRole"
    $body = @{
        identifier = $aadGroup.objectId;
        groupUserAccessRight = $pbiRole;
        principalType = "Group";
    } | ConvertTo-Json -Depth 100
    Invoke-PowerBIRestMethod -Method Post -Url "groups/$($workspace.id)/users" -Body $body -Verbose
}