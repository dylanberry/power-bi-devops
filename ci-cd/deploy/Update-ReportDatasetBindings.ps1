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

Write-Host "Get workspace $WorkspaceName"
$groups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups?`$filter=$groupFilter" `
  -Headers $headers
$groupId = $groups.value[0].id

Write-Host "Get datasets"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets" `
  -Headers $headers

$dataset = $datasets.value | ? name -eq $DatasetName

if (!$dataset) { throw "Dataset $DatasetName not found in $WorkspaceName" }

try {
  $ReportList = $ReportList | ConvertFrom-Json
  Write-Host "Report List:"
  Write-Host $ReportList
}
catch {
  Write-Host "Report List is Empty"
}

Write-Host "Get reports"
$reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/reports" `
  -Headers $headers

if (-not $ReportList) { $ReportList = $reports.value.name }

Write-Host "Rebind reports to $($dataset.name)"
foreach ($reportName in $ReportList) {
  $report = $reports.value | Where-Object {$_.name -like $reportName -and $_.datasetId -eq $($dataset.id)}
  

  if ($report) {
    $datasetJson = @{ "datasetId" = "$($dataset.id)" } | ConvertTo-Json -Compress
    
    echo "Rebinding report $($report.name) to $($dataset.name)"

    Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$groupId/reports/$($report.id)/Rebind" `
      -Headers $headers `
      -Body $datasetJson -ContentType 'application/json' -Verbose
  }
}