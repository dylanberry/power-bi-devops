[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$PbiToolsPath,

    [Parameter(Mandatory=$true)]
    [string]$ReportSourceFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$PbixFolderPath,

    [Parameter()]
    [string[]]$ReportList
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType "directory" -Path $PbixFolderPath -Force
cd $PbixFolderPath

$pbiToolsCmdPath = Join-Path $PbiToolsPath -ChildPath 'pbi-tools.exe'
echo "pbi-tools command path $pbiToolsCmdPath"
$env:Path += ";$PbiToolsPath"

$env:PBITOOLS_LogLevel = 'Verbose'
try {
    $ReportList = $ReportList | ConvertFrom-Json
    Write-Host "Report List:"
    Write-Host $ReportList
  }
  catch {
    Write-Host "Report List is Empty"
  }
foreach($reportName in $ReportList) {
    $reportFilePath = Join-Path $ReportSourceFolderPath -ChildPath "$reportName"
    echo "Compiling $reportName from $reportFilePath"
    pbi-tools compile-pbix $reportFilePath -overwrite

    # $compiledPbixFilePath = Join-Path $PWD -ChildPath "$($reportSourceFolder.Name).pbix"
    # echo "Moving compiled PBIX file from $compiledPbixFilePath to $PbixFolderPath"
    # Move-Item $compiledPbixFilePath $PbixFolderPath
}