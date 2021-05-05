#PS script to deploy SQLWATCH during appveyor builds

param(
    [string]$SqlInstance,
    [string]$Database,
    [string]$Dacpac
    )

$DACPAC = Get-ChildItem -Recurse -Filter $Dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

sqlpackage.exe /a:Publish /sf:"$($DACPAC.FullName)" /tdn:$Database /tsn:$SqlInstance
exit $LASTEXITCODE