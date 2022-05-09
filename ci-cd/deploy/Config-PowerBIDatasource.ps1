[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$BimFilePath,

    [Parameter(Mandatory=$true)]
    [string]$DatasourceName,

    [Parameter(Mandatory=$true)]
    [string]$SqlServer,

    [Parameter(Mandatory=$true)]
    [string]$SqlDatabase
)

$ErrorActionPreference = 'Stop'

echo "Load the bim contents from $BimFilePath"
$bim = Get-Content $BimFilePath | ConvertFrom-Json -Depth 100

echo "Set the datasource $DatasourceName"
$bim.model.dataSources | % {
    if ($_.name -ne $DatasourceName) { continue }
    $_.connectionDetails.address.server = $SqlServer
    $_.connectionDetails.address.database = $SqlDatabase
}

echo "Save the bim contents"
$bim | ConvertTo-Json -Depth 100 | Out-File $BimFilePath