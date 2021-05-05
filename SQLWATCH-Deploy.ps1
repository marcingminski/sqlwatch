#PS script to deploy SQLWATCH during appveyor builds

param(
    [string]$SqlInstance,
    [string]$Database,
    [string]$Dacpac,
    [switch]$RunAsJob
    )

$Dacpac = "SQLWATCH-TESTER.dacpac"
$DACPACPath = Get-ChildItem -Recurse -Filter $Dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($RunAsJob) {

    Start-Job -ScriptBlock { 
        param([string]$arguments)
        Start-Process sqlpackage.exe -ArgumentList $arguments -NoNewWindow -PassThru 
        } -ArgumentList "/a:Publish /sf:`"$($DACPACPath.FullName)`" /tdn:$Database /tsn:$SqlInstance"
}
else {
    sqlpackage.exe /a:Publish /sf:"$($DACPACPath.FullName)" /tdn:$Database /tsn:$SqlInstance
    exit $LASTEXITCODE
}