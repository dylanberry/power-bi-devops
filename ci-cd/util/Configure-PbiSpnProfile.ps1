
az login # --allow-no-subscriptions --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId

$resource = 'https://analysis.windows.net/powerbi/api'
$token = az account get-access-token --resource $resource | ConvertFrom-Json

$authToken = $token.accessToken
$headers = @{"Authorization"="Bearer $authToken"}

$baseUri = "https://api.powerbi.com/v1.0/myorg"

echo "Get capacities"
$capacities = Invoke-RestMethod -Method GET -Uri  "$baseUri/capacities" `
    -Headers $headers
    
$capacities.value

$groupFilter = "name eq '$WorkspaceName'"

echo "Get workspace $WorkspaceName"
$groups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups?`$filter=$groupFilter" `
    -Headers $headers
$groupId = $groups.value[0].id

$capacity = $capacities.value | ? displayName -like 'Premium Per User*'

echo "Add $WorkspaceName to $($capacity.displayName) capacity plan"
$body = @{ 
    "targetCapacityObjectId" = $capacity.Id
    "workspacesToAssign" = @($workspace.Id)
} | ConvertTo-Json -Compress

Invoke-RestMethod -Method POST -Uri "$baseUri/admin/capacities/AssignWorkspaces" `
    -Headers $headers `
    -Body $body -ContentType 'application/json' -Verbose