[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$PbiToolsPath,

    [Parameter(Mandatory=$true)]
    [string]$ReportSourceFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$PbixFolderPath
)

New-Item -ItemType "directory" -Path $ReportSourceFolderPath -Force

$pbiToolsCmdPath = Join-Path $PbiToolsPath -ChildPath 'pbi-tools.exe'
echo "pbi-tools command path $pbiToolsCmdPath"
$env:Path += ";$PbiToolsPath"

$env:PBITOOLS_LogLevel = 'Verbose'

$reportFiles = Get-ChildItem -Path $PbixFolderPath -Recurse -Filter *.pbix

foreach ($reportFile in $reportFiles) {
    echo "Extracting $($reportFile.FullName)"
    pbi-tools extract $reportFile.FullName

    $extractedPbixFolderPath = Join-Path $PbixFolderPath -ChildPath $reportFile.BaseName
    echo "Moving extracted PBIX Folder from $extractedPbixFolderPath to $reportSourceFolderPath"
    Move-Item $extractedPbixFolderPath $reportSourceFolderPath
}