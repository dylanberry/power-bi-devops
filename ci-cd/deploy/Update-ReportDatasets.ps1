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
$groupId = $groups.value[0].id

echo "Get datasets"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets" `
    -Headers $headers

echo "Get reports"
$reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/reports" `
    -Headers $headers

echo "Rebind datasets to reports and update dataset datasource credentials"
foreach ($dataset in $datasets.value) {
  echo "Found dataset $($dataset.name)"
  $reportFilter = $dataset.name.ToLower().Replace(' dataset', '')
  $reportFilter
  $report = $reports.value | ? name -like "*$reportFilter"
  echo "Found report $($report.name)"
  $datasetJson = @{ "datasetId"="$($dataset.id)" } | ConvertTo-Json -Compress

  Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$groupId/reports/$($report.id)/Rebind" `
      -Headers $headers `
      -Body $datasetJson -ContentType 'application/json' -Verbose

  echo "Get datasources"
  $datasources = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets/$($dataset.id)/datasources" `
      -Headers $headers

  foreach ($datasource in $datasources.value) {
    try {      
      echo "Datasource type: $($datasource.datasourceType)"
      $datasource
      $datasourceDetails = Invoke-RestMethod -Method GET -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
            -Headers $headers -Verbose

      switch ($datasource.datasourceType) {
        'Sql' {  }
        'File' {  }
        Default { #'AzureBlobs' 'Web'
          $datasourceDetails = Invoke-RestMethod -Method GET -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
            -Headers $headers -Verbose
          $datasourceDetails
    
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
          
          Invoke-RestMethod -Method PATCH -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
            -Headers $headers `
            -Body $credentialJson -ContentType 'application/json' -Verbose
        }
      }
    }
    catch {
      echo $_.Exception
    }
  }
}