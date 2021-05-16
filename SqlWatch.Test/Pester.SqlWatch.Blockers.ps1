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
$global:OutputSqlErrors=$false

$TestDatabaseName = New-SqlWatchTestDatabase
$global:SqlWatchDatabaseTest=$TestDatabaseName

Describe "$($SqlInstance): Blocking chains capture" -Tag 'BlockingChains' {

    Context 'Creating blocking chains' {        

        It "Head blocker initiated" {
            $(New-HeadBlocker).State | Should -Be "Running"    
        }

        It 'Blocked process initiated' {
            Start-Sleep -s 5
            $(Measure-Command { New-BlockedProcess }).TotalSeconds | Should -BeGreaterThan 20 -Because "The blocking transaction lasts at least 25 seconds"
        }
    }    

    Context 'Checking that we are able to read XES and offload blocking chains to table' {

        Start-Sleep -Seconds 10 #to make sure event has been dispatched

        It "Getting blocking chains from XES" {
            $sql = "exec [dbo].[usp_sqlwatch_logger_xes_blockers];";
            { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
        }

        It "New blocking chain recorded" {
            $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_xes_blockers] where event_time >= (select max(date) from [$($SqlWatchDatabaseTest)].[dbo].[sqlwatch_pester_ref])"
            $result = Invoke-SqlWatchCmd -Query $sql
            $result.cnt | Should -BeGreaterThan 0 -Because 'Blocking chain count should have increased'
        }
    }    
}