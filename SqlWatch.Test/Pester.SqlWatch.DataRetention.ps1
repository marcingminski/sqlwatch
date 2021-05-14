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

Describe "$($SqlInstance): Data Retention" -Tag 'DataRetention' {

    Context 'Running Data Retention Procedure' {

        It 'Data Retention Procedure should run successfuly' {
            $sql = "exec [dbo].[usp_sqlwatch_internal_retention];"
            { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw    
        }

        It 'Data Purge Procedure should run successfuly' {
            $sql = "exec [dbo].[usp_sqlwatch_purge_orphaned_snapshots];"
            { Invoke-SqlWatchCmd -Query $sql } | Should -Not -Throw    
        }
    }

    Context 'Checking Snapshot Retention Policy is being applied' {
  
        It 'The snapshot [<_.snapshot_type_desc>] should respect retention policy' -ForEach $(Get-SqlWatchSnapshotTypes) {

            $sql = "select cnt=count(*)
            from dbo.sqlwatch_logger_snapshot_header h
            where h.snapshot_type_id = $($_.snapshot_type_id)
            and datediff(day,h.snapshot_time,getutcdate()) > $($_.snapshot_retention_days)
            and $($_.snapshot_retention_days) > 0"
    
            $result = Invoke-SqlWatchCmd -Query $sql
            $result.cnt | Should -Be 0 -Because "There should not be any rows beyond the max age."
    
        }
    }

    Context 'Checking Last Seen Retention is being applied' {

        It 'The "Last Seen" Retention in Table <_.TableName> should respect the configuration setting' -ForEach $(Get-SqlWatchTablesWithLastSeenDates) {
        
            $sql = "select cnt=count(*) 
            from $($_.TableName) 
            where datediff(day,date_last_seen,getutcdate()) > [dbo].[ufn_sqlwatch_get_config_value](2,null)"

            $result = Invoke-SqlWatchCmd -Query $sql
            $result.cnt | Should -Be 0 -Because "There should not be any rows beyond the max age." 
        }           
    }
}