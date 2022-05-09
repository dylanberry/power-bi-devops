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

  [Parameter(Mandatory = $true)]
  [string]$DatasourceName,

  [Parameter(Mandatory = $true)]
  [string]$SqlUserName,

  [Parameter(Mandatory = $true)]
  [string]$SqlPassword
)

function Update-SqlDatasourceCredentials {
  param (
    $SqlUserName,
    $SqlPassword,
    $datasource
  )

  echo "Create HTTP request body to patch datasource credentials"
  $userNameJson = "{""name"":""username"",""value"":""$SqlUserName""}"
  $passwordJson = "{""name"":""password"",""value"":""$SqlPassword""}"

  $credentialJson = @{
    "credentialDetails" = @{
      "credentials"                 = "{""credentialData"":[ $userNameJson, $passwordJson ]}"
      "credentialType"              = "Basic"
      "encryptedConnection"         = "NotEncrypted"
      "encryptionAlgorithm"         = "None"
      "privacyLevel"                = "Organizational"
    }
  } | ConvertTo-Json -Compress -Depth 100

  echo "Set SQL datasource credentials"
  $url = "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)"
  Invoke-RestMethod -Method PATCH -Uri $url `
    -Headers $headers `
    -Body $credentialJson -ContentType 'application/json' 
  
}

$ErrorActionPreference = 'Stop'

az login --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId

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

if (!$dataset) { throw "Dataset $DatasetName not found in $WorkspaceName" }

echo "Get datasources"
$datasources = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets/$($dataset.id)/datasources" `
  -Headers $headers
  
$datasource = $datasources.value[0] #.name | ? name -eq $DatasourceName

if (!$datasource) { throw "Datasource $DatasourceName not found in $DatasetName" }
  
Update-SqlDatasourceCredentials $SqlUserName $SqlPassword $datasource $SqlResourceGroupName