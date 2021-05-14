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

$TestDatabaseName = New-SqlWatchTestDatabase
$global:SqlWatchDatabaseTest=$TestDatabaseName

Describe "$($SqlInstance): Broker Activation" -Tag "Broker" {

    It 'Migrating from Agent Jobs to Broker' {
        $sql = "exec [dbo].[usp_sqlwatch_internal_migrate_jobs_to_queues]"
        { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw
    }

    Context 'Checking Broker Data Collection' {
        $m = 12
        for($i = 0; $i -lt $m; $i++) {
            It "Data is being collected via Broker. Waiting for new data... $($i+1) out of $($m)" {
                $HeaderCount1 = $(Get-SqlWatchHeaderRowCount).Headers
                Start-Sleep -s 5
                $HeaderCount2 = $(Get-SqlWatchHeaderRowCount).Headers
                $HeaderCount2 | Should -BeGreaterThan $HeaderCount1
            }    
        }
    }

    $ErrorLogErrors = $(Get-SqlServerErrorLogRecordsDuringTest -String1 'sqlwatch_exec' -String2 'Error') 

    if ($ErrorLogErrors.Count -eq 0) {
        $Skip = $true
    } else {
        $Skip = $false
    }

    It 'No ERRORLOG entries raised by the broker' -Skip:$Skip -ForEach $ErrorLogErrors {
        $_.Text | Should -BeNullOrEmpty
    }
};