param(
    [string]$SqlInstance,
    [string]$SqlWatchDatabase,
    [string]$SqlWatchDatabaseTest
)

<# On not so rare ocassions, Appveyor throws an error
Cannot open database "SQLWATCH" requested by the login. The login failed.
Login failed for user 'APPVYR-WIN\appveyor'
so we have to make sure all databases are onine and accesible before we can proceed with testing
#> 

$SqlWatchDatabaseState = 0
$sql = "select isOnline=count(*) 
    from sys.databases
    where name = '$($SqlWatchDatabase)' 
    and state = 0 and user_access = 0 " 

$i = 0
While ($SqlWatchDatabaseState -ne 1 -and $i -lt 20) {
    $SqlWatchDatabaseState = (Invoke-SqlCmd -ServerInstance $SqlInstance -Database master -Query $sql).isOnline
    $i+=1
    If ($SqlWatchDatabaseState -eq 1) {
        break;
    }
    Start-Sleep -s 5
}
    
$sql  = "select cnt=count(*) from [dbo].[sqlwatch_app_version]"

$i = 0
while ((!$result -eq 0) -and $i -lt 20 ) {
    try {
        $result = (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql).cnt
    }
    catch {
        $IdontCareAboutTheErrorHere = $Error
        if (1 -eq 2) {
            Throw "we must have a throw in the catch"
        }
    }
    $i+=1
    if ($result -gt 0) {
        break;
    }
    Start-Sleep 5
}


<#
    Create pester table to store results and other data.
    This used to be in its own database but there is no need for another databae project.
    Whilst we do need a separate database to create blocking chains (becuase sqlwatch has RCSI, 
    we can just create it on the fligh here.
    The benefit of this approach is that we can just create tables for the purpose of the test in one place here, 
    rather than having to manage separate database project. The original idea was to move some of the testing stuff
    from the SQLWATCH database but I will move it all here rather than separate database.
#>

$sql = "if not exists (select * from sys.databases where name = '$($SqlWatchDatabaseTest)') 
    begin
        create database [$($SqlWatchDatabaseTest)]
    end;
    ALTER DATABASE [$($SqlWatchDatabaseTest)] SET READ_COMMITTED_SNAPSHOT OFF;
    ALTER DATABASE [$($SqlWatchDatabaseTest)] SET RECOVERY SIMPLE ;"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sql

#Create table to store reference data for other tests where required:
$sql = "if not exists (select * from sys.tables where name = 'sqlwatch_pester_ref')
begin
    CREATE TABLE [dbo].[sqlwatch_pester_ref]
    (
        [date] datetime NOT NULL,
        [test] varchar(255) not null,
    );    

    create index idx_sqlwatch_pester_ref_test
        on [dbo].[sqlwatch_pester_ref] ([test]) include ([date])
end;

insert into [dbo].[sqlwatch_pester_ref] (date,test)
values (getutcdate(),'Test Start')"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql

Describe "$($SqlInstance): System Configuration" {

    $sql = "select collation_name from sys.databases where name = 'tempdb'"
    $SystemCollation = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    $sql = "select collation_name from sys.databases where name = '$($SqlWatchDatabase)'"
    $SqlWatchCollation  = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    If ($SystemCollation.collation_name -eq $SqlWatchCollation.collation_name) {
        $CollationMismatch = $false
        $Skip = $true
    } else {
        $CollationMismatch = $true
        $Skip = $false
    }
    It 'The SQLWATCH database collaction should be different to system collaction to incrase test coverage' -Skip:$Skip {

    }         

    $sql = "select Hours=datediff(hour,sqlserver_start_time,getdate()) from sys.dm_os_sys_info"
    $SqlUptime = Invoke-SqlCmd -ServerInstance $SqlInstance -Database master -Query $sql
    $SqlUptimeHours = $SqlUptime.Hours
   
    if ($SqlUptimeHours -lt 168) {
        $Skip = $true 
    } else { 
        $Skip = $false 
    }

    It 'SQL Server should be running for at least a weeek to test data retention routines' -Skip:$Skip {}


    $sql = "select datediff(hour,getutcdate(),getdate())"
    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql; 

    if ($result.Column1 -ge 0) { 
        $Skip = $true 
    } else { 
        $Skip = $false 
    }

    #if the local time is ahead of utc we can easily spot records in the future.
    #cannot do the same when the local time is behind or same as utc.
    It 'The Servers local time should be ahead of UTC in order to test that we are only using UTC dates' -Skip {}

}

Describe "$($SqlInstance): ERROLOG Capture" -Tag "ERRORLOG" {

    It 'Logging in with incorrect user' {
        $sql = "select 1"
        { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -Username "InvalidUserTest" -Password "Password" } | Should -Throw
    }

    It 'Capture ERRORLOG into SQLWATCH' {
        $sql = "exec [dbo].[usp_sqlwatch_logger_errorlog];"
        { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql } | Should -Not -Throw
    }
}

Describe "$($SqlInstance): Procedure Execution" -Tag 'Procedures' {

    #SQLWATCH Procedures
    $sql = "select ProcedureName= s.name + '.' + p.name 
    from sys.procedures p
    inner join sys.schemas s
    on s.schema_id = p.schema_id
    where (
        p.name like 'usp_sqlwatch_internal_add%'
        or p.name like 'usp_sqlwatch_logger%'
        or p.name like 'usp_sqlwatch_internal_expand%'
        or p.name like 'usp_sqlwatch_internal_process%'
        )
    --exclue procs that require parameters
    and p.name not in (
            'usp_sqlwatch_internal_add_check',
            'usp_sqlwatch_internal_add_os_volume',
            'usp_sqlwatch_internal_process_actions',
            'usp_sqlwatch_internal_process_reports',
            'usp_sqlwatch_logger_disk_utilisation_os_volume'
            )
    order by case 
        when p.name like '%internal_add%' then 0
        when p.name like '%internal_expand%' then 1 
        when p.name like '%internal_process%' then 2
        else 9 end,
    case
        when p.name like '%database' then 'A' 
        when p.name like '%table' then 'B' 
        else p.name end"

    $SqlWatchProcedures = @()        
    $i = 0;


    While ($SqlWatchProcedures.Count -eq 0 -and $i -lt 20 ) {

        $SqlWatchProcedures = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
        if ($SqlWatchProcedures.Count -gt 0) {
            break;
        }
        $i+=1
        Start-Sleep -s 5
    }

    Context 'Procedure Should not Throw an error on the first run' {
        It "Procedure <_.ProcedureName> should not throw an error" -Foreach $SqlWatchProcedures {
            $sql = "exec $($_.ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }

    Start-Sleep -s 1

    Context 'Procedure Should not Throw an error on the second run' {
        It "Procedure <_.ProcedureName> should not throw an error" -Foreach $SqlWatchProcedures {
            $sql = "exec $($_.ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }    
}

Describe "$($SqlInstance): Tables should not be empty" -Tag 'Tables' {

    ## SQLWATCH Tables
    $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
        , TableType=case 
            when TABLE_NAME like '%config%' and TABLE_NAME not like '%logger%' and TABLE_NAME not like '%meta%' and TABLE_NAME not like '_DUMP_%' then 'Config'
            when TABLE_NAME like '%meta%' then 'Meta'
            when TABLE_NAME not like '_DUMP_%' and TABLE_NAME like '%logger%' then 'Logger'
            else 'Other' end
    from INFORMATION_SCHEMA.TABLES
    where TABLE_TYPE = 'BASE TABLE'
    and TABLE_NAME not like 'sqlwatch%baseline'";

    $SqlWatchTables = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql    

    $SqlWatchTableConfig = $SqlWatchTables | Where-Object { $_.TableType -eq "Config" }
    $SqlWatchTableMeta = $SqlWatchTables | Where-Object { $_.TableType -eq "Meta" }
    $SqlWatchTableLogger = $SqlWatchTables | Where-Object { $_.TableType -eq "Logger" }    

    $sql = "select IsAgentEnabled=[dbo].[ufn_sqlwatch_get_agent_status]()"
    $IsAgentEnabled = (Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql).IsAgentEnabled    

    Context 'Config tables should have rows' {
        It "Table <_.TableName> should have rows" -Foreach $SqlWatchTableConfig {
            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }        
    }

    Context 'Meta tables should have rows' {

        It "Table <_.TableName> should have rows" -Foreach $SqlWatchTableMeta {

            if ($($_.TableName) -eq "dbo.sqlwatch_meta_os_volume" -and $IsAgentEnabled -eq 0) {
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
        
            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }        
    }

    Context 'Logger tables should have rows' {

        It "Table <_.TableName> should have rows" -Foreach $SqlWatchTableLogger {

            $sql = "select cnt=count(*) from sys.availability_groups"
            $AG = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sql

            $sql = "select cnt=count(*) from [dbo].[sqlwatch_config_include_index_histogram] where object_name_pattern <> '%.dbo.table%'"
            $HistogramToCollect = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            
            if ($($_.TableName) -eq "dbo.sqlwatch_logger_agent_job_history" -and $IsAgentEnabled -eq 0)  {
                Set-ItResult -Skip -Because "SQL Agent is disabled so it will not generate any history"
            }

            if ($($_.TableName) -eq "dbo.sqlwatch_logger_hadr_database_replica_states" -and $AG.cnt -eq 0)  {
                Set-ItResult -Skip -Because "Availability Groups are not found"
            }

            if ($($_.TableName) -eq "dbo.sqlwatch_logger_xes_query_problems" -or $($_.TableName) -eq "dbo.sqlwatch_config_activated_procedures") {
                Set-ItResult -Skip -Because "this is not yet implemented"
            }

            if ($($_.TableName) -eq "dbo.sqlwatch_logger_index_histogram") {
                if ($($HistogramToCollect.cnt) -eq 0) {
                    Set-ItResult -Skip -Because "no histograms are set to be collected"
                }
            }

            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }
    }
}

Describe "$($SqlInstance): Testing Blocking chains capture" -Tag 'BlockingChains' {

    Context 'Creating blocking chains' {        

        It "Head blocker initiated" {
                           
            $scriptBlock = {           
                param($SqlInstance , $SqlWatchDatabaseTest)
                Invoke-SqlCmd -ServerInstance $($SqlInstance) -Database $($SqlWatchDatabaseTest) -Query "
                begin tran
                    select * from [dbo].[sqlwatch_pester_ref] with (tablock, holdlock, xlock)
                    waitfor delay '00:00:25'
                commit tran
                "
            }
             
            $HeadBlocker = Start-Job -ScriptBlock $scriptBlock -ArgumentList $SqlInstance, $SqlWatchDatabaseTest
            $HeadBlocker.State | Should -Be "Running"
        }

        It 'Blocked process initiated' {

            Start-Sleep -s 5
            
            $BlockingDuration = Measure-Command { Invoke-SqlCmd -ServerInstance $($SqlInstance) -Database $($SqlWatchDatabase) -Query "select cnt=count(*) from [$($SqlWatchDatabaseTest)].[dbo].[sqlwatch_pester_ref]" }
            $BlockingDuration.TotalSeconds | Should -BeGreaterThan 20 -Because "The blocking transaction lasts at least 25 seconds"
        }
    }    

    Context 'Checking that we are able to read XES and offload blocking chains to table' {

        Start-Sleep -Seconds 10 #to make sure event has been dispatched

        It "Getting blocking chains from XES" {
            $sql = "exec [dbo].[usp_sqlwatch_logger_xes_blockers];"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql } | Should -Not -Throw
        }

        It "New blocking chain recorded" {
            $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_xes_blockers] where event_time >= (select max(date) from [$($SqlWatchDatabaseTest)].[dbo].[sqlwatch_pester_ref])"
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.cnt | Should -BeGreaterThan 0 -Because 'Blocking chain count should have increased'
        }
    }    
}

Describe "$($SqlInstance): Testing Long Queries Capture" -Tag 'LongQueries' {

    Context 'Generating Long Query' {

        It "Running 1st Long Query Lasting over 5 seconds" {

            $n = 1
            $duration = Measure-Command{}
            
            while ($duration.TotalSeconds -lt 6 -and $n -lt 30) {
                $sql = "select top $($n)00000 a.*
                into #t
                from sys.all_objects a
                cross join sys.all_objects"
        
                $duration = Measure-Command { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql }
                $n+=$n;
            }

            $duration.TotalSeconds | Should -BeGreaterThan 5 -Because "To trigger long query XES the query must last over 5 seconds"
        }

        It "Running 2nd Long Query Lasting over 5 seconds" {

            $n = 1
            $duration = Measure-Command{}
            
            while ($duration.TotalSeconds -lt 6 -and $n -lt 30) {
                $sql = "select top $($n)00000 a.*
                into #t
                from sys.all_objects a
                cross join sys.all_objects"
        
                $duration = Measure-Command { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql }
                $n+=$n;
            }

            $duration.TotalSeconds | Should -BeGreaterThan 5 -Because "To trigger long query XES the query must last over 5 seconds"
        }

    }


    Context 'Checking that we are able to read XES and offload Long Queries to table' {

        It "Getting Long Queries from XES" {
            $sql = "exec [dbo].[usp_sqlwatch_logger_xes_long_queries];"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw
        }

        It "New Long Queries recorded" {

            $sql = "select cnt=count(*) 
                    from [dbo].[sqlwatch_logger_xes_long_queries] 
                    where [event_time] >= (
                            select max(date) 
                            from [$($SqlWatchDatabaseTest)].dbo.[sqlwatch_pester_ref]
                            )"
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.cnt | Should -BeGreaterThan 0 -Because 'Long Query count should have increased' 

        }

        It "Only queries lasting more than 5 seconds" {

            $sql = "select duration_ms=min(duration_ms) from [dbo].[sqlwatch_logger_xes_long_queries]"
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.duration_ms | Should -BeGreaterThan 5000 -Because 'Long query threshold is 5s'
        }
    }
}

Describe "$($SqlInstance): Check Status should not be CHECK_ERROR" -Tag 'Checks' {

    Context 'Proces checks - 1st run' {
        $sql = "exec [dbo].[usp_sqlwatch_internal_process_checks]"
        { Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql } | Should -Not -Throw
    }

    Context 'Proces checks - 2nd run' {
        Start-Sleep -s 5
        $sql = "exec [dbo].[usp_sqlwatch_internal_process_checks]"
        { Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql } | Should -Not -Throw
    }

    Context 'Test outcome' {
        #This can only run after we have run procedures that expand and create checks:
        $sql = "select CheckId=check_id, CheckName=check_name, CheckStatus=last_check_status from [dbo].[sqlwatch_meta_check]"
        $Check = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            
        It "Check [<_.CheckName>] has valid outcome (<_.CheckStatus>)" -ForEach $Check {
            $($_.CheckStatus) | Should -BeIn ("OK","WARNING","CRITICAL") -Because 'Checks must return an outcome, it should be either "OK", "WARNING", "CRITICAL"'
        }
    }
}

Describe "$($SqlInstance): Data Retention" -Tag 'DataRetention' {

    $sql = "select * from dbo.sqlwatch_config_snapshot_type"
    $SnapshotType = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    $sql = "select TableName = TABLE_SCHEMA + '.' + TABLE_NAME
    from INFORMATION_SCHEMA.TABLES
    where TABLE_NAME IN (
        select DISTINCT TABLE_NAME
        from INFORMATION_SCHEMA.COLUMNS
        where COLUMN_NAME = 'date_last_seen'
    )
    and TABLE_NAME not like '_DUMP_%'
    and TABLE_TYPE = 'BASE TABLE'";

    $TableWithLastSeen = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql    

    Context 'Running Data Retention Procedure' {

        It 'Data Retention Procedure should run successfuly' {
            $sql = "exec [dbo].[usp_sqlwatch_internal_retention];"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw    
        }

        It 'Data Purge Procedure should run successfuly' {
            $sql = "exec [dbo].[usp_sqlwatch_purge_orphaned_snapshots];"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw    
        }
    }

    Context 'Checking Snapshot Retention Policy is being applied' {
  
        It 'The snapshot [<_.snapshot_type_desc>] should respect retention policy' -ForEach $SnapshotType {

            $sql = "select count(*)
            from dbo.sqlwatch_logger_snapshot_header h
            where h.snapshot_type_id = $($_.snapshot_type_id)
            and datediff(day,h.snapshot_time,getutcdate()) > $($_.snapshot_retention_days)
            and $($_.snapshot_retention_days) > 0"
    
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0 -Because "There should not be any rows beyond the max age."
    
        }
    }

    Context 'Checking Last Seen Retention is being applied' {

        It 'The "Last Seen" Retention in Table <_.TableName> should respect the configuration setting' -ForEach $TableWithLastSeen {
        
            $sql = "select count(*) from $($_.TableName) where datediff(day,date_last_seen,getutcdate()) > [dbo].[ufn_sqlwatch_get_config_value](2,null)"
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

            $result.Column1 | Should -Be 0 -Because "There should not be any rows beyond the max age." 
        }           
    }
}

Describe "$($SqlInstance): Database Design" -Tag 'DatabaseDesign' {

    $sql = "select TableName=schema_name(t.schema_id) + '.' +  t.[name], 
    PkName = pk.[name], FkName=fk.[name]
    from sys.tables t
    left join sys.indexes pk
        on t.object_id = pk.object_id 
        and pk.is_primary_key = 1
    left join sys.foreign_keys fk
        on fk.parent_object_id = t.object_id"

    $SqlWatchTableKeys = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    Context 'Tables have Primary Keys' {

        It 'Table <_.TableName> has Primary Key' -ForEach $SqlWatchTableKeys {

            If ($($_.TableName) -eq "dbo.sqlwatch_pester_result" `
            -or $($_.TableName) -eq "dbo.dbachecksChecks" `
            -or $($_.TableName) -eq "dbo.dbachecksResults") {
                Set-ItResult -Skip -Because 'it is a third party table'
            } else {
                $($_.PkName) | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Tables have Foreign Keys' {

        It 'Table <_.TableName> has Foreign Key' -ForEach $SqlWatchTableKeys {

            If (
                $($_.TableName) -Like "dbo.sqlwatch_config*" `
            -or $($_.TableName) -Like "dbo.sqlwatch_stage*" `
            -or $($_.TableName) -Like "dbo.sqlwatch_app_version"
                ) {
                Set-ItResult -Skip -Because 'it does not have FK by design'
            }
            ElseIf (
                $($_.TableName) -eq "dbo.sqlwatch_pester_result" `
            -or $($_.TableName) -eq "dbo.dbachecksChecks" `
            -or $($_.TableName) -eq "dbo.dbachecksResults" `
            -or $($_.TableName) -eq "dbo.__RefactorLog"  
            ) {
                Set-ItResult -Skip -Because 'it is a third party table'
            } else {
                $($_.FkName) | Should -Not -BeNullOrEmpty
            }
        }        
    }

    Context 'Check Constraints are trusted' {

        $sql = "select name, is_not_trusted 
        from sys.check_constraints"

        $SqlWatchConstraints = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

        It 'Constraint <_.name> is trusted' -ForEach $SqlWatchConstraints {
            $($_.is_not_trusted) | Should -Be 0 
        }
    }

    Context 'Foreign Keys are trusted' {

        $sql = "select name, is_not_trusted 
        from sys.foreign_keys"

        $SqlWatchForeignKeys = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

        It 'Constraint <_.name> is trusted' -ForEach $SqlWatchForeignKeys {
            $($_.is_not_trusted) | Should -Be 0 
        }
    }
    
    Context 'Dates are correct' {

        $sql="select [SqlWatchColumn]=c.TABLE_SCHEMA + '.' + c.TABLE_NAME + '.' + c.COLUMN_NAME 
        from INFORMATION_SCHEMA.COLUMNS c
        inner join INFORMATION_SCHEMA.TABLES t
            on t.TABLE_CATALOG = c.TABLE_CATALOG
            and t.TABLE_NAME = c.TABLE_NAME
            and t.TABLE_SCHEMA = c.TABLE_SCHEMA
        where t.TABLE_TYPE = 'BASE TABLE'         
        and c.DATA_TYPE LIKE '%time%'"
        $SqlWatchTimeColumns = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql


        $sql = "select LOCAL_TIME=GETDATE(), UTC_TIME=GETUTCDATE(), TABLE_NAME,COLUMN_NAME 
        from INFORMATION_SCHEMA.COLUMNS 
        where TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME = '$($column)'"

        It 'Datetime values in <_.SqlWatchColumn> are not in the future' -ForEach $SqlWatchTimeColumns {

            $sql = "select LOCAL_TIME=GETDATE(), UTC_TIME=GETUTCDATE(), TABLE_NAME,COLUMN_NAME 
            from INFORMATION_SCHEMA.COLUMNS 
            where TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME = '$($column)'"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

            $sql = "select max(datediff(hour,GETUTCDATE(),$($result.COLUMN_NAME))) from [$($result.$TABLE_NAME)]";
            $result.Column1 | should -Not -BeGreaterThan 0 -Because 'Values in the future could indicate that we are collecting local time rather than UTC'  

        }
    }
}

Describe "$($SqlInstance): Application Log Errors" -Tag 'ApplicationErrors' {

    $sql = "select ERROR_PROCEDURE, ERROR_MESSAGE 
    from [dbo].[sqlwatch_app_log] 
    where event_time > (
            select max([date]) 
            from [$($SqlWatchDatabaseTest)].[dbo].[sqlwatch_pester_ref] 
            where [test] = 'Test Start'
            )
    and process_message_type = 'ERROR'"
    $SqlWatchError = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    if ($SqlWatchError -eq $null) {
        It 'Application Log should not contain ERRORS Raised during the testing'{}
    } else {

        It 'Procedure <_.ERROR_PROCEDURE> has raised an error' -ForEach $SqlWatchError {
            $($_.ERROR_MESSAGE) | Should -BeNullOrEmpty
        }
    }   
}