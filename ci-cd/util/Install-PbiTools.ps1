[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$PbiToolsPath
)

$pbiToolsCmdPath = Join-Path $pbiToolsPath -ChildPath 'pbi-tools.exe'
if (Test-Path $pbiToolsCmdPath -PathType Leaf) {
    echo "pbi-tools found at $pbiToolsCmdPath, skipping install."
}
else {
    
    $mkdirResult = mkdir $pbiToolsPath -Force

    try {
        pushd $pbiToolsPath
        $pbiToolsUrl = "https://api.github.com/repos/action-bi-toolkit/pbi-tools/releases/latest"
        
        $response = Invoke-WebRequest $pbiToolsUrl -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        
        $assetResponse = Invoke-WebRequest $content.assets_url -UseBasicParsing
        $assetContent = $assetResponse.Content | ConvertFrom-Json
        
        $fileName = Split-Path -Path $assetContent.browser_download_url[0] -Leaf

        $downloadZipFile = Join-Path $pbiToolsPath -ChildPath $fileName
        $downloadResponse = Invoke-WebRequest $assetContent.browser_download_url[0] -OutFile $downloadZipFile -UseBasicParsing
        
        $expandResult = Expand-Archive $downloadZipFile -DestinationPath $pbiToolsPath -Force
        
        $env:Path += ";$pbiToolsPath"
        $env:PBITOOLS_LogLevel = 'Verbose'
    }
    finally {
        popd
    }
}