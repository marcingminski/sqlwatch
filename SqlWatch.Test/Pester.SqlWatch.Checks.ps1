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

Describe "$($SqlInstance): Check Status should not be CHECK_ERROR" -Tag 'Checks' {

    Context 'Proces checks - 1st run' {
        $sql = "exec [dbo].[usp_sqlwatch_internal_process_checks]"
        { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
    }

    Context 'Proces checks - 2nd run' {
        Start-Sleep -s 5
        $sql = "exec [dbo].[usp_sqlwatch_internal_process_checks]"
        { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
    }

    Context 'Expanding checks' {
        $sql = "exec [dbo].[usp_sqlwatch_internal_expand_checks];"
        { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
    }

    Context 'Test outcome' {
        It "Check [<_.CheckName>] has valid outcome (<_.CheckStatus>)" -ForEach $(Get-SqlWatchChecks) {
            $($_.CheckStatus) | Should -BeIn ("OK","WARNING","CRITICAL") -Because 'Checks must return an outcome, it should be either "OK", "WARNING", "CRITICAL"'
        }
    }
}