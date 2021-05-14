#PS script to deploy SQLWATCH during appveyor builds

param(
    [string]$SqlInstance,
    [string]$Database,
    [string]$Dacpac,
    [switch]$RunAsJob
    )

$DACPACPath = Get-ChildItem -Recurse -Filter $Dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($RunAsJob) {

    $JobName = "Deploying " + $SqlInstance
    Start-Job -Name $JobName -ScriptBlock { 
        param([string]$arguments)
        Start-Process sqlpackage.exe -ArgumentList $arguments -NoNewWindow -PassThru 
        } -ArgumentList "/a:Publish /sf:`"$($DACPACPath.FullName)`" /tdn:$Database /tsn:$SqlInstance"
}
else {
    sqlpackage.exe /a:Publish /sf:"$($DACPACPath.FullName)" /tdn:$Database /tsn:$SqlInstance
    exit $LASTEXITCODE
}