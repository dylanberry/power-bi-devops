[CmdletBinding()]
param (

    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$ClientId,

    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,

    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [string]$BimFolderPath
)

Install-Module -Name SqlServer -RequiredVersion 21.1.18256
Import-Module -Name SqlServer

$connectionString = "Datasource=powerbi://api.powerbi.com/v1.0/$TenantId/$WorkspaceName;User ID=app:$ClientId@$TenantId;Password=$ClientSecret"

$datasetFilePaths = gci $BimFolderPath -Filter *.bim -File | Select FullName
$failedFilePaths = @()
foreach($datasetFilePath in $datasetFilePaths) {
    try {
        echo "Uploading dataset $($datasetFilePath.FullName)"
        Invoke-ASCmd -ConnectionString $connectionString -InputFile $datasetFilePath.FullName
    }
    catch {
        Resolve-PowerBIError -Last
        $failedFilePaths += $datasetFilePath
    }
}

if ($failedFilePaths.Length -gt 0) {
    $failedFilePathsString = $failedFilePaths -join '`n'
    throw "The following dataset files failed to import: $failedFilePathsString"
}