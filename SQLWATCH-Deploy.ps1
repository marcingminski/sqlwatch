#PS script to deploy SQLWATCH during appveyor builds

param([string[]]$SqlInstances)

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$PSScriptRoot

$DACPAC = Get-ChildItem -Path "$PSScriptRoot\RELEASE\" -Recurse -Filter SQLWATCH.dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1


ForEach ( $SqlInstance in $SqlInstances ) {
        sqlpackage.exe /a:Publish /sf:"$($DACPAC.FullName)" /tdn:SQLWATCH /tsn:$SqlInstance
}