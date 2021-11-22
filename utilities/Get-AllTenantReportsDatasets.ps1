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

echo "Get all groups (workspaces)"
$allGroups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups" `
    -Headers $headers

foreach ($group in $allGroups.value | ? isOnDedicatedCapacity) {
    $WorkspaceName = $group.name
    
    $groupFilter = "name eq '$WorkspaceName'"

    echo "Get workspace $WorkspaceName"
    $groups = Invoke-RestMethod -Method GET -Uri "$baseUri/groups?`$filter=$groupFilter" `
        -Headers $headers
    $groupId = $groups.value[0].id

    echo "Get datasets"
    $datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets" `
        -Headers $headers
    $datasetList = @{}

    echo "Get reports"
    $reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/reports" `
        -Headers $headers

    echo "Get datasources"
    foreach ($dataset in $datasets.value) {
        $datasetInfo = @{ "dataset" = $dataset }
    
        echo "Get datasources for $($dataset.name)"
        $datasources = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets/$($dataset.id)/datasources" `
            -Headers $headers
        
        $datasourceList = @()
        foreach ($datasource in $datasources.value | ? datasourceType -ne 'Extension') {
            $datasourceInfo = @{ "datasource" = $datasource }
            try {
                $datasourceDetails = Invoke-RestMethod -Method GET -Uri "$baseUri/gateways/$($datasource.gatewayId)/datasources/$($datasource.datasourceId)" `
                    -Headers $headers
                $datasourceInfo += @{ "datasourceDetails" = $datasourceDetails }
            }
            catch {
                echo "Could not get gateway datasource. Dataset: $($dataset.name); DatasourceType: $($datasource.datasourceType); GatewayId: $($datasource.gatewayId)"
            }
            $datasourceList += $datasourceInfo
        }
        $datasetInfo += @{ "datasources" = $datasourceList }
    
        $datasetList += @{$dataset.name = $datasetInfo }
    }

    echo $datasetList | ConvertTo-Json -Depth 100
}