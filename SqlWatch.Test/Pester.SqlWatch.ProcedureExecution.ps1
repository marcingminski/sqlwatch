param(
    [string]$SqlInstance,
    [string]$SqlWatchDatabase,
    [string]$SqlWatchDatabaseTest,
    [string[]]$RemoteInstances,
    [string]$SqlWatchImportPath,
    [string]$Modules
)


Get-Item -Path $Modules | Import-Module -Force

$global:SqlInstance=$SqlInstance
$global:SqlWatchDatabase=$SqlWatchDatabase

Describe "$($SqlInstance): Procedure Execution" -Tag 'Procedures' {

    $m = 2
    for($i = 0; $i -lt $m; $i++) {
        Context "Procedure Should not Throw an error on run $($i+1)" {
            It "Procedure <_.ProcedureName> should not throw an error" -Foreach $(Get-SqlWatchProcedures) {
                $sql = "exec $($_.ProcedureName);"
                { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw 
            }
        }
        Start-Sleep -s 3
    }
}