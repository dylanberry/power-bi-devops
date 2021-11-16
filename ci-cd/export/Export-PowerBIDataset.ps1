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

$assemblyName = 'Microsoft.Identity.Client.dll'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    Install-Package Microsoft.Identity.Client -RequiredVersion 4.6.0 -Force -Scope CurrentUser -Destination . -SkipDependencies
    $assemblyItem = gci -Path '.\Microsoft.Identity.Client.4.6.0\lib\netcoreapp2.1\' -Recurse -Filter "$assemblyName*"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)
}

$assemblyName = 'Microsoft.AnalysisServices.Core.dll'
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | ? ManifestModule -like $assemblyName)) {
    Install-Package Microsoft.AnalysisServices.NetCore.retail.amd64 -RequiredVersion 19.22.0.1 -Force -Scope CurrentUser -Destination . -SkipDependencies
    $assemblyItem = gci -Recurse -Filter "$assemblyName*"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)

    $assemblyItem = gci -Recurse -Filter "$assemblyName*"
    [System.Reflection.Assembly]::LoadFrom($assemblyItem.FullName)

    $assemblyItem = gci -Recurse -Filter "$assemblyName*"
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