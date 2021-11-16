[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,

    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,

    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName
)

$ErrorActionPreference = 'Stop'

az login --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
#az login

$resource = 'https://analysis.windows.net/powerbi/api'
$token = az account get-access-token --resource $resource | ConvertFrom-Json

$authToken = $token.accessToken
$headers = @{"Authorization"="Bearer $authToken"}

$baseUri = "https://api.powerbi.com/v1.0/myorg"

$groupFilter = "name eq '$WorkspaceName'"

echo "Get workspace $WorkspaceName"
$groups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups?`$filter=$groupFilter" `
    -Headers $headers

echo "Get datasets"
$dataSets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$($groups.value[0].id)/datasets" `
    -Headers $headers

echo "Get reports"
$reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$($groups.value[0].id)/reports" `
    -Headers $headers

echo "Rebind reports to datasets"
$datasetJson = @{ "datasetId"="$($dataSets.value[0].id)" } | ConvertTo-Json -Compress

Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$($groups.value[0].id)/reports/$($reports.value[0].id)/Rebind" `
    -Headers $headers `
    -Body $datasetJson -ContentType 'application/json' -Verbose

echo "Rebind reports to datasets"
$datasources = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$($groups.value[0].id)/datasets/$($dataSets.value[0].id)/datasources" `
    -Headers $headers

foreach ($datasource in $datasources.value) {
  Invoke-RestMethod -Method GET -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
    -Headers $headers -Verbose

  echo 'Update datasource credentials'
  $credentialJson = @{
    "credentialDetails"=@{
      "credentialType"= "Anonymous"
      "credentials"='{"credentialData":""}'
      "encryptedConnection"="Encrypted"
      "encryptionAlgorithm"="None"
      "privacyLevel"="Public"
      "useEndUserOAuth2Credentials"=$False
    }
  } | ConvertTo-Json -Compress

  echo $credentialJson
  Invoke-RestMethod -Method PATCH -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
    -Headers $headers `
    -Body $credentialJson -ContentType 'application/json' -Verbose
}