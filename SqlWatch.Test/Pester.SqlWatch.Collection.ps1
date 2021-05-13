param(
    [string]$SqlInstance,
    [string]$SqlWatchDatabase,
    [string]$SqlWatchDatabaseTest,
    [string[]]$RemoteInstances,
    [string]$SqlWatchImportPath
)


Get-Item -Path ./SqlWatch.Test/*.psm1 | Import-Module -Force

$global:SqlInstance=$SqlInstance
$global:SqlWatchDatabase=$SqlWatchDatabase
$global:OutputSqlErrors=$false

Describe "$($SqlInstance): Procedure Execution" -Tag 'Procedures' {

    Context 'Procedure Should not Throw an error on the first run' {
        It "Procedure <_.ProcedureName> should not throw an error" -Foreach $(Get-SqlWatchProcedures) {
            $sql = "exec $($_.ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }

    Context 'Procedure Should not Throw an error on the second run' {

        Start-Sleep -s 5
        It "Procedure <_.ProcedureName> should not throw an error" -Foreach $(Get-SqlWatchProcedures) {
            $sql = "exec $($_.ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }    

    Context 'Procedure Should not Throw an error on the third run' {

        Start-Sleep -s 5
        It "Procedure <_.ProcedureName> should not throw an error" -Foreach $(Get-SqlWatchProcedures) {
            $sql = "exec $($_.ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }
}

Describe "$($SqlInstance): Tables should not be empty" -Tag 'Tables' {

    It "Table <_.TableName> should have rows" -Foreach $(Get-SqlWatchTables) {    

        $SqlConfiguration = Get-SqlConfiguration
                
        if ($($_.TableName) -Like "*baseline*" -and $($SqlConfiguration.SqlWatchBaselines) -gt 0)  {
            Set-ItResult -Skip -Because "no baseline is defined"
        }            

        if ($($_.TableName) -eq "dbo.sqlwatch_meta_action_queue" -and $($SqlConfiguration.SqlWatchActions) -eq 0)  {
            Set-ItResult -Skip -Because "no SQLWATCH action is enabled"
        }            
       
        if ($($_.TableName) -Like "*index_missing*" -and $SqlConfiguration.SqlUptimeHours -lt 24) {
            Set-ItResult -Skip -Because "SQL Server needs a longer uptime to capture missing indexes"
        }

        if (   
            (
                $($_.TableName) -eq "dbo.sqlwatch_meta_os_volume" `
            -or $($_.TableName) -eq 'dbo.sqlwatch_logger_disk_utilisation_volume'
            ) `
            -and $SqlConfiguration.SqlAgentStatus -eq $false) {
            Set-ItResult -Skip -Because "OS volume is collected by the Agent Job but SQL Agent is disabled"
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_meta_performance_counter_instance") {
            Set-ItResult -Skip -Because "this is only populated when CLR is enabled"
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_meta_program_name") {
            Set-ItResult -Skip -Because "this is not yet implemented"
        }

        if ($($_.TableName) -Like "*sqlwatch_meta_repository*") {
            
            $sql = "select cnt=count(*) from [dbo].[sqlwatch_config_sql_instance]"
            $Instance = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

            if ($Instance.cnt -eq 1) {
                Set-ItResult -Skip -Because "this only applies to Central Repository"
            }
            else {
                Set-ItResult -Skip -Because "these tables are populated on demand"
            }
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_logger_check_action" -and $($SqlConfiguration.SqlWatchActions) -eq $false)  {
            Set-ItResult -Skip -Because "no SQLWATCH actions are enabled"
        }            

        if ($($_.TableName) -eq "dbo.sqlwatch_logger_whoisactive" -and $($SqlConfiguration.sp_WhoIsActive) -eq $false)  {
            Set-ItResult -Skip -Because "sp_WhoIsActive is not installed"
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_logger_agent_job_history" -and $($SqlConfiguration.SqlAgentStatus) -eq $false)  {
            Set-ItResult -Skip -Because "SQL Agent is disabled so it will not generate any history"
        }

        if (
                 $($_.TableName) -eq "dbo.sqlwatch_logger_hadr_database_replica_states" `
            -and $SqlConfiguration.AvailabiltyGroups -eq 0
            )  {
            Set-ItResult -Skip -Because "Availability Groups are not found"
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_logger_xes_query_problems" `
        -or $($_.TableName) -eq "dbo.sqlwatch_config_activated_procedures") {
            Set-ItResult -Skip -Because "this is not yet implemented"
        }

        if ($($_.TableName) -eq "dbo.sqlwatch_logger_index_histogram" -and $($SqlConfiguration.SqlWatchIndexHistograms) -eq 0) {
            Set-ItResult -Skip -Because "no histograms are set to be collected"

        }            
    
        $sql = "select row_count=count(*) from $($_.TableName)"
        (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql).row_count | Should -BeGreaterThan 0
    }         
}