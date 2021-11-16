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

$datasetFilePaths = gci $BimFolderPath -Filter *.bim -File | Select FullName, Name
$failedFilePaths = @()
foreach($datasetFilePath in $datasetFilePaths) {
    try {
        echo "Coverting bim to tsml"
        $datasetName = $datasetFilePath.Name.Replace('.bim', '')
        $bimFilePath = $datasetFilePath.FullName
        $tsmlFilePath = $datasetFilePath.FullName.Replace('.bim', '.tmsl')

        $bimFileContent = Get-Content $bimFilePath | ConvertFrom-Json

        $tmsl = @{"createOrReplace" = [Ordered]@{}}
        $tmsl.createOrReplace += @{ "object" = @{
                "database" = $datasetName
            }}
        $tmsl.createOrReplace += @{ "database" = [Ordered]@{
                "name" = $datasetName
                "compatibilityLevel" = 1550
            }}
        $tmsl.createOrReplace.database += @{ "model" = $bimFileContent.model }
        $tmsl | ConvertTo-Json -Depth 100 | Out-File $tsmlFilePath

        echo "Uploading dataset $tsmlFilePath"
        Invoke-ASCmd -ConnectionString $connectionString -InputFile $tsmlFilePath
    }
    catch {
        $failedFilePaths += $datasetFilePath
        throw
    }
}

if ($failedFilePaths.Length -gt 0) {
    $failedFilePathsString = $failedFilePaths -join '`n'
    throw "The following dataset files failed to import: $failedFilePathsString"
}