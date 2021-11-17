[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$PbiToolsPath,

    [Parameter(Mandatory=$true)]
    [string]$ReportSourceFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$PbixFolderPath
)

New-Item -ItemType "directory" -Path $PbixFolderPath -Force

$env:Path += ";$pbiToolsPath"
$pbiToolsCmdPath = Join-Path $pbiToolsPath -ChildPath 'pbi-tools.exe'
echo "pbi-tools command path $pbiToolsCmdPath"

$env:PBITOOLS_LogLevel = 'Verbose'

$reportSourceFolders = Get-ChildItem -Path $ReportSourceFolderPath -Directory

foreach ($reportSourceFolder in $reportSourceFolders) {
    echo "Compiling $($reportSourceFolder.Name)"
    pbi-tools compile-pbix $reportSourceFolder.FullName

    $compiledPbixFilePath = Join-Path '$(Build.SourcesDirectory)' -ChildPath "$($reportSourceFolder.Name).pbix"
    echo "Moving compiled PBIX file from $compiledPbixFilePath to $PbixFolderPath"
    Move-Item $compiledPbixFilePath $PbixFolderPath
}