#PS script to deploy SQLWATCH during appveyor builds

param([string]$SqlInstance)

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$DACPAC = Get-ChildItem -Path "$PSScriptRoot\RELEASE\" -Recurse -Filter SQLWATCH.dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

sqlpackage.exe /a:Publish /sf:"$($DACPAC.FullName)" /tdn:SQLWATCH /tsn:$SqlInstance
exit $LASTEXITCODE
