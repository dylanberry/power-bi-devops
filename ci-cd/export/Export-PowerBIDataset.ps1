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
    [string]$ToolsFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$BimFolderPath
)

$assemblyName = 'Microsoft.Identity.Client'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    Install-Package Microsoft.Identity.Client -RequiredVersion 4.25.0 -Force -Scope CurrentUser -Destination $ToolsFolderPath -SkipDependencies
    $assemblyItem = gci -Path "$ToolsFolderPath\$((gci -Directory -Filter "$assemblyName*").Name)\lib\netcoreapp2.1\" -Recurse -Filter "$assemblyName.dll"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)
}

$assemblyName = 'Microsoft.AnalysisServices.Core'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    Install-Package Microsoft.AnalysisServices.NetCore.retail.amd64 -RequiredVersion 19.22.0.1 -Force -Scope CurrentUser -Destination $ToolsFolderPath -SkipDependencies
    $assemblyItem = gci -Path $ToolsFolderPath -Recurse -Filter "$assemblyName.dll"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)
}

$assemblyName = 'Microsoft.AnalysisServices.Tabular'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    $assemblyItem = gci -Path $ToolsFolderPath -Recurse -Filter "$assemblyName.dll"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)
}

$assemblyName = 'Microsoft.AnalysisServices.Tabular.Json'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    $assemblyItem = gci -Path $ToolsFolderPath -Recurse -Filter "$assemblyName.dll"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)
}

$connectionString = "Provider=MSOLAP;Datasource=powerbi://api.powerbi.com/v1.0/$TenantId/$WorkspaceName;User ID=app:$ClientId@$TenantId;Password=$ClientSecret"

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
try {
    $server.Connect($connectionString)
    
    New-Item -ItemType "directory" -Path $BimFolderPath -Force

    foreach ($database in $server.Databases) {
        $databaseJson = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($database, $null)
        $databaseJson | Out-File "$BimFolderPath/$($database.Name).bim"
    }
}
catch {
    $_.Exception
}