[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$UserId
)

$clientId = $env:clientId
$clientSecret = $env:clientSecret
$tenantId = $env:tenantId

$ErrorActionPreference = 'Stop'

az login --allow-no-subscriptions --service-principal --username $clientId --password $clientSecret --tenant $tenantId
# az login

$resource = 'https://analysis.windows.net/powerbi/api'
$token = az account get-access-token --resource $resource | ConvertFrom-Json

$authToken = $token.accessToken
$headers = @{"Authorization" = "Bearer $authToken" }

$baseUri = "https://api.powerbi.com/v1.0/myorg"

Invoke-RestMethod -Headers $headers `
    -Method GET `
    -Uri "$baseUri/admin/pipelines/"

Invoke-RestMethod -Headers $headers `
    -Method POST `
    -Uri "$baseUri/admin/pipelines/6f09c458-49ca-459d-aac3-e3fa4cff9f86/users" `
    -ContentType 'application/json' `
    -Body "{ `"accessRight`": `"Admin`", `"identifier`": $UserId, `"principalType`": `"User`" }"