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

az login --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
#az login

$resource = 'https://analysis.windows.net/powerbi/api'
$token = az account get-access-token --resource $resource | ConvertFrom-Json
$authToken = $token.accessToken

$groupFilter = "name eq '$EnvironmentName'"

echo "Get workspace $EnvironmentName"
$groups = Invoke-RestMethod -Method GET -Uri "https://api.powerbi.com/v1.0/myorg/groups?`$filter=$groupFilter" `
    -Headers @{"Authorization"="Bearer $authToken"}
$groups.value

echo "Get datasets"
$dataSets = Invoke-RestMethod -Method GET -Uri "https://api.powerbi.com/v1.0/myorg/groups/$($groups.value[0].id)/datasets" `
    -Headers @{"Authorization"="Bearer $authToken"}
$dataSets.value

echo "Get reports"
$reports = Invoke-RestMethod -Method GET -Uri "https://api.powerbi.com/v1.0/myorg/groups/$($groups.value[0].id)/reports" `
    -Headers @{"Authorization"="Bearer $authToken"}
$reports.value

echo "Rebind reports to datasets"
$datasetJson = @{ "datasetId"="$($dataSets.value[0].id)" } | ConvertTo-Json -Compress

Invoke-RestMethod -Method POST -Uri "https://api.powerbi.com/v1.0/myorg/groups/$($groups.value[0].id)/reports/$($reports.value[0].id)/Rebind" `
    -Headers @{ "Authorization"="Bearer $authToken" } `
    -Body $datasetJson -ContentType 'application/json' -Verbose

echo "Rebind reports to datasets"
$datasources = Invoke-RestMethod -Method GET -Uri "https://api.powerbi.com/v1.0/myorg/groups/$($groups.value[0].id)/datasets/$($dataSets.value[0].id)/datasources" `
    -Headers @{"Authorization"="Bearer $authToken"}
$datasources.value

foreach ($datasource in $datasources.value) {
  Invoke-RestMethod -Method GET -Uri "https://api.powerbi.com/v1.0/myorg/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
    -Headers @{"Authorization"="Bearer $authToken"} -Verbose

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
  Invoke-RestMethod -Method PATCH -Uri "https://api.powerbi.com/v1.0/myorg/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
    -Headers @{ "Authorization"="Bearer $authToken" } `
    -Body $credentialJson -ContentType 'application/json' -Verbose
}