param(
    $SqlInstance,
    $SqlWatchDatabase,
    $MinSqlUpHours,
    $LookBackHours
)

Write-Host "Testing $SqlInstance"

$sql = "select datediff(hour,sqlserver_start_time,getdate()) from sys.dm_os_sys_info"
$result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
$SqlUpHours = $result.Column1

$SqlWatchDatabaseTest = "SQLWATCH_TEST"

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
end;"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql


Describe 'Procedure Execution' {
    
    Context 'Collector jobs must be disabled and not running before procedure test to avoid clashing' {

        It 'SQLWATCH Jobs are disabled' {
            $sql = "SELECT running_jobs=count(*)
            FROM msdb.dbo.sysjobactivity AS sja
            INNER JOIN msdb.dbo.sysjobs AS sj 
            ON sja.job_id = sj.job_id
            WHERE sja.start_execution_date IS NOT NULL
               AND sja.stop_execution_date IS NULL
               AND sj.name like 'SQLWATCH%'
            "
           
            $RunnigJobs = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $RunnigJobs.running_jobs | Should -Be 0 -Because "SQLWATCH Jobs must not be running before we execute collection during the test." 
        }
    }

    BeforeAll {

        Start-Sleep -Seconds 2

        $sql = "select p.name 
        from sys.procedures p
        where (
            name like 'usp_sqlwatch_internal_add%'
            or name like 'usp_sqlwatch_logger%'
            or name like 'usp_sqlwatch_internal_expand%'
            )
        --not procedures with parameters as we dont know what param to pass
        and name not in (
            select distinct p.name 
            from sys.procedures p
            inner join sys.parameters r
                on r.object_id = p.object_id
        )
        order by case when p.name like '%internal$' then 1 else 2 end,
        case
            when p.name like '%database' then 'A' 
            when p.name like '%table' then 'B' 
            else p.name end"

        $Procedures = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

        $TestCases = @();
        $Procedures.ForEach{$TestCases += @{ProcedureName = $_.name }}               

    } 

    Context 'Check That Procedures Execute OK on the First Run' {

        It 'The Procedure [<ProcedureName>] should not throw an error' -TestCases $TestCases {

            Param($ProcedureName)

            $sql = "exec $($ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        
        }
    }

    Context 'Check That Procedures Execute OK on the Second Run' {

        It 'The Procedure [<ProcedureName>] should not throw an error' -TestCases $TestCases {

            Param($ProcedureName)

            $sql = "exec $($ProcedureName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        
        }           
    }
}

Describe 'Table Content' {

    Context 'Config tables should have data' {

        BeforeAll {

            $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
            from INFORMATION_SCHEMA.TABLES
            where TABLE_NAME not like '_DUMP_%'
            and TABLE_NAME like '%config%'
            and TABLE_NAME not like '%logger%'
            and TABLE_TYPE = 'BASE TABLE'";
        
            $Tables = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
            $TestCases = @();
            $Tables.ForEach{$TestCases += @{TableName = $_.TableName }}                    

        }

        It 'Table <TableName> should have rows' -TestCases $TestCases {
            Param($TableName)
        
            $sql = "select row_count=count(*) from $TableName"

            try {
                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            } 
            catch {
                $result = 0
            }            
            $result.row_count | should -BeGreaterThan 0 -Because 'Config Tables with no rows indicate development issues.'    
        }        
    }

    Context 'Meta tables should have data' {

        BeforeAll {

            $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
            from INFORMATION_SCHEMA.TABLES
            where TABLE_NAME not like '_DUMP_%'
            and TABLE_NAME like '%meta%'
            and TABLE_TYPE = 'BASE TABLE'";
        
            $Tables = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
            $TestCases = @();
            $Tables.ForEach{$TestCases += @{TableName = $_.TableName }}        

        }

        It 'Table <TableName> should have rows' -TestCases $TestCases {
            Param($TableName)
        
            $sql = "select row_count=count(*) from $TableName"

            try {
                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            } 
            catch {
                $result = 0
            }            
            $result.row_count | should -BeGreaterThan 0 -Because 'Meta Tables with no rows indicate configuration issues.'    
        }        
    }

    Context 'Logger tables should have data' {

        BeforeAll {

            $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
            from INFORMATION_SCHEMA.TABLES
            where TABLE_NAME not like '_DUMP_%'
            and TABLE_NAME like '%logger%'
            and TABLE_TYPE = 'BASE TABLE'";
        
            $Tables = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
            $TestCases = @();
            $Tables.ForEach{$TestCases += @{TableName = $_.TableName }}                    

        }

        It 'Table <TableName> should have rows' -TestCases $TestCases {
            Param($TableName)
        
            $sql = "select row_count=count(*) from $TableName"

            try {
                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            } 
            catch {
                $result = 0
            }            
            $result.row_count | should -BeGreaterThan 0 -Because 'Logger Tables with no rows indicate collector issues.'    
        }        

    }
}

Describe 'Test Blocking Chains Capture' {

    Context 'Creating reference data for blocking chains' {

        It "Reference data created" {
            #create blocking chain
            $sql = "insert into [dbo].[sqlwatch_pester_ref] (date,test)
            values (GETUTCDATE(),'Blocking Chain');"

            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }

    Context 'Creating blocking chains' {

        It "Blocking chains created" {

            $scriptBlock1 = {           
                param($SqlInstance , $SqlWatchDatabaseTest)
                Invoke-SqlCmd -ServerInstance $($SqlInstance) -Database $($SqlWatchDatabaseTest) -Query "
                begin tran
                select * from [dbo].[sqlwatch_blocking_chain] with (tablock, holdlock, xlock)
                waitfor delay '00:00:25'
                commit tran
                waitfor delay '00:00:2'"
            }
             
            $job1 = Start-Job -Name "JobBlk1" -ScriptBlock $scriptBlock1 -ArgumentList $SqlInstance, $SqlWatchDatabaseTest
      
           $scriptBlock2 = {           
                param($SqlInstance , $SqlWatchDatabaseTest)
                Invoke-SqlCmd -ServerInstance $($SqlInstance) -Database $($SqlWatchDatabaseTest) -Query "select * from [dbo].[sqlwatch_blocking_chain]"
            }
             
            $Job2 = Start-Job -Name "JobBlk2" -ScriptBlock $scriptBlock2 -ArgumentList $SqlInstance, $SqlWatchDatabaseTest
    
            Wait-Job $job1
            Wait-Job $job2

            $job2.State | Should -Be "Completed" 

        }


    }

    Context 'Checking that we are able to read XES and offload blocking chains to table' {

        Start-Sleep -Seconds 10 #to make sure event has been dispatched

        It "Getting blocking chains from XES" {
            $sql = "exec [dbo].[usp_sqlwatch_logger_xes_blockers];"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql } | Should -Not -Throw
            
        }

        It "New blocking chain recorded" {
            $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_xes_blockers] where event_time >= (select max(date) from [$($SqlWatchDatabaseTest)].[dbo].[sqlwatch_pester_ref] where test = 'Blocking Chain')"
    
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.cnt | Should -BeGreaterThan 0 -Because 'Blocking chain count should have increased'
        }
    }
}

Describe 'Test Long Queries Capture' {

    Context 'Generating Test data' {

        BeforeAll {
           
            # ref data
            $sql = "insert into [dbo].[sqlwatch_pester_ref] (date,test)
            values (getutcdate(),'Long Query');"
            Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabaseTest -Query $sql

        }

        It "Running Long Query Lasting over 5 seconds" {

            $n = 1
            $duration = Measure-Command{}
            
            while ($duration.TotalSeconds -lt 6 -and $n -lt 10) {
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

            $sql = "select cnt=count(*) from [dbo].[sqlwatch_logger_xes_long_queries] where [event_time] >= (select max(date) from dbo.[sqlwatch_pester_ref] where test = 'Long Query')"
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

Describe 'Failed Checks' {

    BeforeAll {

        $sql = ""
        $Checks = @(); #thanks Rob https://sqldbawithabeard.com/2017/11/28/2-ways-to-loop-through-collections-in-pester/
        $Checks = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query "select check_id, check_name from [dbo].[sqlwatch_config_check]"
        
        $TestCases = @();
        $Checks.ForEach{$TestCases += @{check_name = $_.check_name }} 

        BeforeAll {

            if ($SqlUpHours -lt $MinSqlUpHours) { $Skip = $true } else { $Skip = $false }

        }        

    }


    Context "Checking for checks that have failed to execute with the CHECK_ERROR outcome" {
  
        It 'Check [<check_name>] executions should never return status of CHECK ERROR' -TestCases $TestCases {

            Param($check_name)

            $sql = "declare @starttime datetime; 

            select @starttime=sqlserver_start_time 
            from sys.dm_os_sys_info

            select count(*) 
                from [dbo].[sqlwatch_config_check] cc 
                left join [dbo].[sqlwatch_logger_check] lc 
                    on cc.check_id = lc.check_id 
                where snapshot_time > dateadd(hour,-$($LookBackHours),getutcdate()) 
                and cc.check_name = '$($check_name)' 
                and lc.check_status like '%ERROR%'
                --skip records after restart as Perf counters will be empty right after restart.
                and lc.snapshot_time > dateadd(minute,2,@starttime)
                "

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0 -Because 'The check results should be "OK", "WARNING" or "CRITICAL". However, checks that fail to execute or return value that is out of bound, will return "CHECK ERROR" status.'

        }
    }

    Context "Checking if checks have outcome" {

    
        It 'Check [<check_name>] should have an outcome' -TestCases $TestCases {
    

            Param($check_name) 

            $sql = "select last_check_status from [dbo].[sqlwatch_meta_check] where check_name = '$($check_name)'"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.last_check_status | Should -BeIn ("OK","WARNING","CRITICAL","CHECK ERROR") -Because 'Checks must return an outcome, it should be either "OK", "WARNING", "CRITICAL" or "CHECK_ERROR"'
     
      }

    }

    Context "Checking for checks that do not respect the execution frequency parameter " {

        BeforeAll {
            $sql = "
            exec [dbo].[usp_sqlwatch_internal_process_checks];
            waitfor delay '00:00:05';
            exec [dbo].[usp_sqlwatch_internal_process_checks]
            "
            Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql


            if ($SqlUpHours -lt $MinSqlUpHours) { $Skip = $true } else { $Skip = $false }
    
        }

        
         It 'Check [<check_name>] should respect execution frequency setting' -TestCases $TestCases -Skip:$Skip {
     
            Param($check_name) 

            $sql = "select check_frequency_minutes=isnull(check_frequency_minutes,1) from [dbo].[sqlwatch_config_check] where check_name = '$($check_name)'"
            $check_frequency_minutes = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

            $sql = "select cc.check_id, lc.snapshot_time, RN=ROW_NUMBER() over (partition by cc.check_id order by lc.snapshot_time)
            into #t
            from [dbo].[sqlwatch_logger_check] lc
            inner join dbo.sqlwatch_config_check cc
	            on lc.check_id = cc.check_id
            where snapshot_time > dateadd(hour,-$($LookBackHours),getutcdate())
            and cc.check_name = '$($check_name)'

            create clustered index icx_tmp_t on #t (snapshot_time)

            select
	            min_check_frequency_minutes_calculated=ceiling(avg(datediff(second,c1.snapshot_time,c2.snapshot_time)/60.0))
            from #t c1
            left join #t c2
	            on c1.check_id = c2.check_id
	            and c1.RN = c2.RN -1
            "

                # Because sql agent is syncronous, there is no guarantee that checks will always run at the same interval. There will be +/- few seconds or even a couple of minutes
                # If the check takes longer to execute, the gap between the second execution will be smaller than it should be. 
                # We are going to allow some deviation of +/- 1 minute
                $minvalue=$check_frequency_minutes.check_frequency_minutes-1
                $maxvalue=$check_frequency_minutes.check_frequency_minutes+1
                $value=$check_frequency_minutes.check_frequency_minutes
                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
                $result.min_check_frequency_minutes_calculated | Should -BeIn ($minvalue,$value,$maxvalue) -Because 'The agent job that invokes the check engine runs every 1 minute but not all checks should run every 1 minute. There is a [check_frequency_minutes] column that tells us how often each check should run. This value must be respected otherwise all checks will run every 1 minute which will create additional load on the server'

        }
    }
}


Describe 'Test database design' {

    BeforeAll {

        $sql = "select datediff(hour,getutcdate(),getdate())"
        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;        

        if ($result.Column1 -ge 0) { $Skip = $true } else { $Skip = $false }
    }

    $TimeFields = @();
    $sql = "select [column]=TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS where DATA_TYPE LIKE '%time%'"
    $TimeFields = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

    $TestCases = @();
    $TimeFields.ForEach{$TestCases += @{column = $_.column}}    

    It 'Datetime values in <column> should not be greater than UTC' -TestCases $TestCases -Skip:$Skip {
        Param($column)
    
        $sql = "select LOCAL_TIME=GETDATE(), UTC_TIME=GETUTCDATE(), TABLE_NAME,COLUMN_NAME 
        from INFORMATION_SCHEMA.COLUMNS 
        where TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME = '$($column)'"

        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

        $sql = "select top 1 datediff(hour,GETUTCDATE(),$($result.COLUMN_NAME)) from [$($result.$TABLE_NAME)] order by $($result.COLUMN_NAME) desc";
        $result.Column1 | should -Not -BeGreaterThan 0 -Because 'Values in the future indicate local time rather than UTC'    
    }
}

Describe 'Test Check Results' {

    BeforeAll {

        if ($SqlUpHours -lt $MinSqlUpHours) { $Skip = $true } else { $Skip = $false }

    }     

    It 'The Latest Data Backup Check should return correct result' -Skip:$Skip {
        ## Use dbatools as a baseline
        $LastFullBackup = Get-DbaLastBackup -SqlInstance $SqlInstance | Sort-Object LastFullBackup -Descending | Select-Object -first 1 
        $LastDiffBackup = Get-DbaLastBackup -SqlInstance $SqlInstance | Sort-Object LastDiffBackup -Descending | Select-Object -first 1 

        $LastFullBackupAgeDays = $(New-TimeSpan -Start $LastFullBackup.LastFullBackup -End (Get-Date)).TotalDays
        $LastDiffBackupAgeDays = $(New-TimeSpan -Start $LastDiffBackup.LastDiffBackup -End (Get-Date)).TotalDays        

        if ($LastDiffBackupAgeDays -lt $LastFullBackupAgeDays) {
            [int]$LastDataBackupAgeDays = $LastDiffBackupAgeDays
        } else {
            [int]$LastDataBackupAgeDays = $LastFullBackupAgeDays
        }

        ## this is the sql query from the check itself as we have to compare live values:
        ## check_id -18        
        $sql = "select check_query from dbo.sqlwatch_meta_check where check_id = -18"
        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

        $sql = $result.check_query -replace "@output","output"
        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

        $result.output | should -Be $LastDataBackupAgeDays 
    }

    It 'The Latest Log Backup Check should return correct result' -Skip:$Skip {
        ## Use dbatools as a baseline
        $LastLogBackup = Get-DbaLastBackup -SqlInstance $SqlInstance | Sort-Object LastLogBackup -Descending | Select-Object -first 1 

        [int]$LastLogBackupAgeMinutes = $(New-TimeSpan -Start $LastLogBackup.LastLogBackup -End (Get-Date)).TotalMinutes

        ## this is the sql query from the check itself as we have to compare live values:
        ## check_id -17
        $sql = "select check_query from dbo.sqlwatch_meta_check where check_id = -17"
        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

        $sql = $result.check_query -replace "@output","output"
        $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

        $result.output | should -Be $LastLogBackupAgeMinutes 
    }
}

Describe 'Data Retention' {

    Context 'Checking Snapshot Retention Policy is being applied' {

        BeforeAll {

            $SnapshotTypes = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query "select * from sqlwatch_config_snapshot_type"

            $TestCases = @();
            $SnapshotTypes.ForEach{$TestCases += @{SnapshotTypeDesc = $_.snapshot_type_desc }}

        }
  
        It 'Snapshot Type [<SnapshotTypeDesc>] should respect retention policy' -TestCases $TestCases {

            Param($SnapshotTypeDesc)

            $sql = "select count(*)
            from sqlwatch_logger_snapshot_header h
            inner join sqlwatch_config_snapshot_type t
                on h.snapshot_type_id = t.snapshot_type_id
            where datediff(day,h.snapshot_time,getutcdate()) > snapshot_retention_days
            and snapshot_type_desc = '$($SnapshotTypeDesc)'
            and snapshot_retention_days > 0"
    
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0 -Because "There should not be any rows beyond the max age."
    
        }

    }

    Context 'Checking Last Seen Retention Policy is being applied' {

        BeforeAll {

            $sql = "select TABLE_SCHEMA + '.' + TABLE_NAME
            from INFORMATION_SCHEMA.TABLES
            where TABLE_NAME IN (
                select DISTINCT TABLE_NAME
                from INFORMATION_SCHEMA.COLUMNS
                where COLUMN_NAME = 'date_last_seen'
            )
            and TABLE_NAME not like '_DUMP_%'
            and TABLE_TYPE = 'BASE TABLE'";
        
            $Tables = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
            $TestCases = @();
            $Tables.ForEach{$TestCases += @{TableName = $_.Column1 }}

        }

        It 'The "Last Seen" Retention in Table [<TableName>] should respect the configuration setting' -TestCases $TestCases -Skip:$Skip {

            Param($TableName)
        
            $sql = "select count(*) from $($TableName) where datediff(day,date_last_seen,getutcdate()) > [dbo].[ufn_sqlwatch_get_config_value](2,null)"
            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0 -Because "There should not be any rows beyond the max age." 
        }
    }
}

# This MUST be last check
Describe 'Application Errors' {

    Context 'Check Application log for Errors' {

        <# Warnings are OK. Flapping checks or exceeding email thresholds etc.
        It 'Application Log should not contain WARNINGS' {

            $sql = "select count(*) from [dbo].[sqlwatch_app_log]
            where process_message_type = 'WARNING'
            and event_sequence > dateadd(hour,-$($LookBackHours),getutcdate())"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0

        }
        #>
        
        It 'Application Log should not contain ERRORS' {

            $sql = "select count(*) from [dbo].[sqlwatch_app_log]
            where process_message_type = 'ERROR'"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.Column1 | Should -Be 0

        }

    }
}


Write-host "Cleaning up..."
#Cleanup
$sql = "if exists (select * from sys.databses where name = '$($SqlWatchDatabaseTest)'
begin
    drop database [$($SqlWatchDatabaseTest)]
end;"
Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sql