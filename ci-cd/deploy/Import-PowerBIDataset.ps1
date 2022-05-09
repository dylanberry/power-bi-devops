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
    [string]$DatasetName,

    [Parameter(Mandatory=$true)]
    [string]$BimFilePath,

    [Parameter(Mandatory=$true)]
    [string]$DatasourceName,

    [Parameter(Mandatory=$true)]
    [string]$SqlServer,

    [Parameter(Mandatory=$true)]
    [string]$SqlDatabase,

    [Parameter(Mandatory=$true)]
    [string]$TmslOutputPath
)

$ErrorActionPreference = 'Stop'

If(-not(Get-InstalledModule SqlServer -ErrorAction silentlycontinue))
{
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module SqlServer -AllowPrerelease -Confirm:$False -Force -AllowClobber
}
Import-Module -Name SqlServer

$powerBiUri = "powerbi://api.powerbi.com/v1.0/myorg/$($WorkspaceName.Replace(' ', '%20'))"
$connectionString = "Datasource=$powerBiUri;User ID=app:$ClientId@$TenantId;Password=$ClientSecret"

echo "Coverting bim to tmsl"

$bimFileContent = Get-Content $BimFilePath | ConvertFrom-Json -Depth 100

echo "Set the datasource `"$DatasourceName`""
$bimFileContent.model.dataSources | % {
    if ($_.name -ne $DatasourceName) { continue }
    $_.connectionDetails.address.server = $SqlServer
    $_.connectionDetails.address.database = $SqlDatabase
    $_.credential = [Ordered]@{
        AuthenticationKind = "UsernamePassword";
        Username = "sa122";
        EncryptConnection = $true;
        PrivacySetting = "Organizational";
    }
}

if ($bimFileContent.model.defaultPowerBIDataSourceVersion -ne 'powerBI_V3') {
    $bimFileContent.model | Add-Member -NotePropertyName defaultPowerBIDataSourceVersion -NotePropertyValue 'powerBI_V3' -Force
}

$tmsl = @{"createOrReplace" = [Ordered]@{}}
$tmsl.createOrReplace += @{ "object" = @{
        "database" = $DatasetName
    }}
$tmsl.createOrReplace += @{ "database" = [Ordered]@{
        "name" = $DatasetName
        "compatibilityLevel" = 1550
    }}
$tmsl.createOrReplace.database += @{ "model" = $bimFileContent.model }

$tmsl | ConvertTo-Json -Depth 100 | Out-File $TmslOutputPath


echo "Uploading dataset $TmslOutputPath with connectionString $connectionString"
$result = Invoke-ASCmd -ConnectionString $connectionString -InputFile $TmslOutputPath
$resultXml = [xml]$result
if ($resultXml.return.root.Exception) {
    throw "ErrorCode: $($resultXml.return.root.Messages.Error.ErrorCode); Description: $($resultXml.return.root.Messages.Error.Description)"
}