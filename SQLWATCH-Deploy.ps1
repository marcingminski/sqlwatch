#PS script to deploy SQLWATCH during appveyor builds

param(
    [string]$SqlInstance,
    [string]$Database,
    [string]$Dacpac,
    [switch]$RunAsJob
    )

$DACPACPath = Get-ChildItem -Recurse -Filter $Dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($RunAsJob) {

    <# Appveyor would often return:
    Receive-Job : There is an error processing data from the background process. 
    Error reported: Cannot process an element with node type "Text". Only Element and EndElement node types are supported.
    https://stackoverflow.com/questions/24689505/start-process-nonewwindow-within-a-start-job
    #>
    $JobName = "Deploying " + $SqlInstance
    Start-Job -Name $JobName -ScriptBlock { 
        #param([string]$arguments)
        param (
            [string]$SqlInstance,
            [string]$Database,
            [string]$Dacpac
        )
        sqlpackage.exe /a:Publish /sf:"$($Dacpac)" /tdn:$($Database) /tsn:$($SqlInstance)
        #Start-Process sqlpackage.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    } -ArgumentList $SqlInstance, $Database, $($DACPACPath.FullName) | Format-Table
        #} -ArgumentList "/a:Publish /sf:`"$($DACPACPath.FullName)`" /tdn:$Database /tsn:$SqlInstance"
}
else {
    sqlpackage.exe /a:Publish /sf:"$($DACPACPath.FullName)" /tdn:$Database /tsn:$SqlInstance
    exit $LASTEXITCODE
}