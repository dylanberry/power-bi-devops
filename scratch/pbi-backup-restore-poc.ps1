#az login --service-principal -u $env:ClientId -p $env:ClientSecret --tenant $env:TenantId
$token = az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' | ConvertFrom-Json
$headers = @{"Authorization"="Bearer $($token.accessToken)"}
$baseUri = "https://api.powerbi.com/v1.0/myorg"


$WorkspaceName = 'Source'
$ReportName = 'helloworld_pbiservice_1'
$DummyDatasetName = 'blank'

$TargetWorkspaceName = 'Target'
$TargetDatasetName = 'helloworld'
$TargetReportName = 'helloworld_restored'


##### Backup #####

Write-Output "Get workspace $WorkspaceName"
$groups = Invoke-RestMethod -Method GET `
  -Uri "$baseUri/groups?`$filter=name eq '$WorkspaceName'" `
  -Headers $headers
$groupId = $groups.value[0].Id

Write-Host "Get $ReportName report"
$reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/reports" `
  -Headers $headers
$report = $reports.value | ? name -EQ $ReportName

Write-Host "Get $DummyDatasetName dataset"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/datasets" `
  -Headers $headers
$dataset = $datasets.value | ? name -eq $DummyDatasetName
 
$exportReportName = "$($report.name)-export"
$cloneBody = @{ "name" = $exportReportName } | ConvertTo-Json -Compress
Write-Output "Cloning report $($report.name)"
$exportReport = Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$groupId/reports/$($report.id)/Clone" `
  -Headers $headers `
  -Body $cloneBody `
  -ContentType 'application/json'

$rebindBody = @{ "datasetId" = "$($dataset.id)" } | ConvertTo-Json -Compress
Write-Output "Rebinding report $($exportReport.name) to $($dataset.name)"
Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$groupId/reports/$($exportReport.id)/Rebind" `
  -Headers $headers `
  -Body $rebindBody `
  -ContentType 'application/json'

$reportFilePath = Join-Path $PWD.Path "$($ReportName).pbix"
Write-Output "Exporting report $($exportReport.name)"
Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$groupId/reports/$($exportReport.id)/Export?preferClientRouting=true" `
  -Headers $headers -OutFile $reportFilePath



##### Restore #####

Expand-Archive $reportFilePath -Force

Write-Output "Get workspace $TargetWorkspaceName"
$groups = Invoke-RestMethod -Method GET `
  -Uri "$baseUri/groups?`$filter=name eq '$TargetWorkspaceName'" `
  -Headers $headers
$targetGroupId = $groups.value[0].Id

Write-Output "Get datasets"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$targetGroupId/datasets" `
  -Headers $headers
$targetDataset = $datasets.value | ? name -eq $TargetDatasetName

$reportConnectionsFilePath = Join-Path $PWD.Path $ReportName "Connections"

Write-Output "Updating dataset connection string in $reportConnectionsFilePath"
$connections = Get-Content $reportConnectionsFilePath | ConvertFrom-Json
$connections.RemoteArtifacts[0].DatasetId = $targetDataset.id

Write-Output "Saving updated connections file $reportConnectionsFilePath"
$connections | ConvertTo-Json -Depth 32 | Out-File -FilePath $reportConnectionsFilePath -Encoding utf8 -Force

$reportFolder = Join-Path $PWD.Path $ReportName
$restoredReportPath = Join-Path $PWD.Path "$TargetReportName.pbix"
Write-Output "Zipping $reportFolder to $restoredReportPath"
Compress-Archive $reportFolder\* $restoredReportPath -Force

Write-Output "Uploading report $restoredReportPath"
$uri = "$baseUri/groups/$($targetGroupId)/imports?datasetDisplayName=$($TargetReportName).pbix&nameConflict=CreateOrOverwrite"
$boundary = "---------------------------" + (Get-Date).Ticks.ToString("x")
$boundarybytes = [System.Text.Encoding]::ASCII.GetBytes("`r`n--" + $boundary + "`r`n")

$request = [System.Net.WebRequest]::Create($uri)
$request.ContentType = "multipart/form-data; boundary=" + $boundary
$request.Method = "POST"
$request.KeepAlive = $true
$request.Headers.Add("Authorization", "Bearer $($token.accessToken)")
$rs = $request.GetRequestStream()

$rs.Write($boundarybytes, 0, $boundarybytes.Length);
$header = "Content-Disposition: form-data; filename=`"temp.pbix`"`r`nContent-Type: application / octet - stream`r`n`r`n"
$headerbytes = [System.Text.Encoding]::UTF8.GetBytes($header)
$rs.Write($headerbytes, 0, $headerbytes.Length);
$fileContent = [System.IO.File]::ReadAllBytes($restoredReportPath)
$rs.Write($fileContent,0,$fileContent.Length)
$trailer = [System.Text.Encoding]::ASCII.GetBytes("`r`n--" + $boundary + "--`r`n");
$rs.Write($trailer, 0, $trailer.Length);
$rs.Flush()
$rs.Close()

$response = $request.GetResponse()
$stream = $response.GetResponseStream()
$streamReader = [System.IO.StreamReader]($stream)
$content = $streamReader.ReadToEnd() | convertfrom-json
$jobId = $content.id
$streamReader.Close()
$response.Close()
Write-Host "Import job created $jobId"

Start-Sleep -Milliseconds 500

Write-Host "Get reports"
$reports = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$targetGroupId/reports" `
  -Headers $headers
$targetReport = $reports.value | ? name -EQ $TargetReportName

Write-Output "Rebinding report $($targetReport.name) to $($targetDataset.name)"
$rebindBody = @{ "datasetId" = "$($targetDataset.id)" } | ConvertTo-Json -Compress
Invoke-RestMethod -Method POST -Uri "$baseUri/groups/$targetGroupId/reports/$($targetReport.id)/Rebind" `
  -Headers $headers `
  -Body $rebindBody -ContentType 'application/json' -Verbose

Write-Output "Get datasets"
$datasets = Invoke-RestMethod -Method GET -Uri "$baseUri/groups/$targetGroupId/datasets" `
  -Headers $headers
$restoredDataset = $datasets.value | ? name -eq $targetReport.name
Write-Output "Cleaning up dataset"
Invoke-RestMethod -Method Delete -Uri "$baseUri/groups/$targetGroupId/datasets/$($restoredDataset.id)" `
  -Headers $headers `
  -ContentType 'application/json' -Verbose