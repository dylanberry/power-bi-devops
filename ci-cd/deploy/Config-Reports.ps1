[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ClientId,

  [Parameter(Mandatory = $true)]
  [string]$ClientSecret,

  [Parameter(Mandatory = $true)]
  [string]$TenantId,

  [Parameter(Mandatory = $true)]
  [string]$WorkspaceName,

  [Parameter(Mandatory = $true)]
  [string]$DatasetName,

  [Parameter(Mandatory=$true)]
  [string]$ReportSourceFolderPath,

  [Parameter()]
  [string[]]$ReportList
)

$ErrorActionPreference = 'Stop'

az login --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
#az login

$resource = 'https://analysis.windows.net/powerbi/api'
$token = az account get-access-token --resource $resource | ConvertFrom-Json

$authToken = $token.accessToken
$headers = @{"Authorization" = "Bearer $authToken" }

$baseUri = "https://api.powerbi.com/v1.0/myorg"

$groupFilter = "name eq '$WorkspaceName'"

echo "Get workspace $WorkspaceName"
$groups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups?`$filter=$groupFilter" `
  -Headers $headers
$groupId = $groups.value[0].id

echo "Get datasets"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets" `
  -Headers $headers

$dataset = $datasets.value | ? name -eq $DatasetName

$pbiServiceLiveConnectionString = "Data Source=pbiazure://api.powerbi.com;Initial Catalog=$($dataset.id);Identity Provider=`"https://login.microsoftonline.com/common, https://analysis.windows.net/powerbi/api, 7f67af8a-fedc-4b08-8b4e-37c4d127b6cf`";Integrated Security=ClaimsToken"
$analysisServicesDatabaseLiveConnectionString = "Data Source=`"powerbi://api.powerbi.com/v1.0/myorg/$WorkspaceName`";Initial Catalog=$DatasetName;Cube=`"Current Data`""

$pbiModelDatabaseName = $dataset.id
try {
  $ReportList = $ReportList | ConvertFrom-Json
  Write-Host "Report List:"
  Write-Host $ReportList
}
catch {
  Write-Host "Report List is Empty"
}
foreach($reportName in $ReportList) {
    $reportFilePath = Join-Path $ReportSourceFolderPath -ChildPath "$reportName"
    $reportConnectionsFilePath = Join-Path $reportFilePath -ChildPath "Connections.json"


    #Note: These connections schemas from Power BI are subject to change since this approach is not supported
    echo "Updating dataset connection string in $reportConnectionsFilePath"
    $connections = Get-Content $reportConnectionsFilePath | ConvertFrom-Json
    $connections.Version = 3

    if($connections.Connections[0].ConnectionType -eq "pbiServiceLive"){
      $connections.Connections[0].ConnectionString = $pbiServiceLiveConnectionString
      $connections.Connections[0].ConnectionType = "pbiServiceLive"
      $connections.Connections[0].PbiServiceModelId = 3301691
      $connections.Connections[0].PbiModelVirtualServerName = "sobe_wowvirtualserver"
      $connections.Connections[0].PbiModelDatabaseName = $pbiModelDatabaseName
    }    
    elseif ($connections.Connections[0].ConnectionType -eq "analysisServicesDatabaseLive"){
      $connections.Connections[0].ConnectionString = $analysisServicesDatabaseLiveConnectionString
      $connections.Connections[0].ConnectionType = "analysisServicesDatabaseLive"
    }
    else {
      throw "Unknown connection type: " +  $connections.Connections[0].ConnectionType;
    }

    echo "Saving updated connections file $reportConnectionsFilePath"
    $connections | ConvertTo-Json -Depth 32 | Out-File -FilePath $reportConnectionsFilePath -Encoding utf8 -Force
}