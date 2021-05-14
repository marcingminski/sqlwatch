Function Invoke-SqlWatchCmd {
    param (
        [string]$Query
    )

    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $true
        ErrorAction = "Stop"
    }
    return Invoke-SqlCmd @SqlCmdParams -Query $Query;
};

Function Invoke-SqlWatchTestCmd {
    param (
        [string]$Query
    )

    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabaseTest
        OutputSqlErrors = $true
        ErrorAction = "Stop"
    }
    return Invoke-SqlCmd @SqlCmdParams -Query $Query;
};

Function Get-SqlWatchHeaderRowCount {
    $sql = "select Headers=count(*)
    from dbo.sqlwatch_logger_snapshot_header"

    return Invoke-SqlWatchCmd -Query $sql
}
Function Get-SqlWatchTestStartTime {
    $sql = "select TestStartTime=max([date]) 
    from [dbo].[sqlwatch_pester_ref]
    where [test] = 'Test Start'"

    return Invoke-SqlWatchTestCmd -Query $sql;
}
Function Get-SqlWatchAppLogErrorsDuringTest {
    $Since = $(Get-SqlWatchTestStartTime).TestStartTime

    Write-Host $Since
    
    $sql = "select ERROR_PROCEDURE, ERROR_MESSAGE 
    from [dbo].[sqlwatch_app_log] 
    where event_time > isnull(nullif('$($Since)',''),'1970-01-01')
    and process_message_type = 'ERROR'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ERROR_PROCEDURE = $_.ERROR_PROCEDURE; ERROR_MESSAGE = $_.ERROR_MESSAGE }};
    return $Return;   
}

Function Get-SqlServerErrorLogRecordsDuringTest {
    param (
        [string]$String1,
        [string]$String2
    )
    $Since = $(Get-SqlWatchTestStartTime).TestStartTime

    if ($String2 -eq $null) {$String2 = ''};

    $sql = "EXEC sys.xp_readerrorlog 0, 1,  N'$($String1)',N'$($String2)','$($Since)'"
    
    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{LogDate = $_.LogDate; ProcessInfo = $_.ProcessInfo; Text = $_.Text; }};
    return $Return;   
}
Function Get-SqlWatchTablesWithLastSeenDates {
    $sql = "select TableName = TABLE_SCHEMA + '.' + TABLE_NAME
    from INFORMATION_SCHEMA.TABLES
    where TABLE_NAME IN (
        select DISTINCT TABLE_NAME
        from INFORMATION_SCHEMA.COLUMNS
        where COLUMN_NAME = 'date_last_seen'
    )
    and TABLE_NAME not like '_DUMP_%'
    and TABLE_TYPE = 'BASE TABLE'";
    
    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName}};
    return $Return;        
}

Function Get-SqlWatchChecks {
    $sql = "select 
          CheckId=check_id
        , CheckName=check_name
        , CheckStatus=last_check_status 
        from [dbo].[sqlwatch_meta_check]"
    
    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{CheckId = $_.CheckId; CheckName = $_.CheckName; CheckStatus = $_.CheckStatus }};
    return $Return;       
}

Function Get-SqlWatchSnapshotTypes {
    $sql = "select snapshot_type_id,
    snapshot_type_desc,
    snapshot_retention_days,
    collect 
    from dbo.sqlwatch_config_snapshot_type"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{snapshot_type_id = $_.snapshot_type_id; snapshot_type_desc = $_.snapshot_type_desc; snapshot_retention_days = $_.snapshot_retention_days }};
    return $Return;       
}
Function Get-SqlWatchTables {  

    $sql = ";with cte_tables as (
        select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
        , TableType=case 
            when TABLE_NAME like '%config%' and TABLE_NAME not like '%logger%' and TABLE_NAME not like '%meta%' and TABLE_NAME not like '_DUMP_%' then 'Config'
            when TABLE_NAME like '%meta%' then 'Meta'
            when TABLE_NAME not like '_DUMP_%' and TABLE_NAME like '%logger%' then 'Logger'
            else 'Other' end
    from INFORMATION_SCHEMA.TABLES
    where TABLE_TYPE = 'BASE TABLE'
    --and TABLE_NAME not like 'sqlwatch%baseline'
    --and TABLE_NAME not like 'sqlwatch_stage%'
    --and TABLE_NAME like '%sqlwatch%'
    )
    select * from cte_tables
    where TableType <> 'Other'
    order by case 
        when TableType = 'Config' then 1
        when TableType = 'Meta' then 2
        when TableType = 'Logger' then 3
        else 4 end
        ";
    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName }};
    return $Return;      

};

Function Get-SqlWatchTablePKeys {

    $sql = "select TableName=schema_name(t.schema_id) + '.' +  t.[name], 
    PkName = pk.[name]
    from sys.tables t
    left join sys.indexes pk
        on t.object_id = pk.object_id 
        and pk.is_primary_key = 1
    where t.name like '%sqlwatch%'
    order by t.name";
    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName; PkName = $_.PkName}};
    return $Return;

};

Function Get-SqlWatchTableFKeys {

    $sql = ";with cte_fkeys as (
        select TableName=schema_name(t.schema_id) + '.' +  t.[name], 
        FkName = fk.[name]
        from sys.tables t
        left join sys.foreign_keys fk
        on fk.parent_object_id = t.object_id
        where t.name like '%sqlwatch%'
    ) 
    select TableName, FkCount=count(distinct FkName)
    from cte_fkeys
    group by TableName
    order by TableName";

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName; FkCount = $_.FkCount}};
    return $Return;

};

Function Get-CheckConstraints {

    $sql = "select 
            TableName=t.name
        , ConstraintName = s.name
        , IsNotTrusted = s.is_not_trusted
    from sys.check_constraints s
    inner join sys.tables t
        on s.parent_object_id = t.object_id
    where t.name like '%sqlwatch%'";

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName; ConstraintName = $_.ConstraintName; IsNotTrusted = $_.IsNotTrusted}};
    return $Return;
};
Function Get-DefaultConstraints {

    $sql = "select distinct
        ConstraintName = df.name
    from sys.default_constraints df
    inner join sys.tables t
        on t.object_id = df.parent_object_id
        where t.name like '%sqlwatch%'";

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ConstraintName = $_.ConstraintName}};
    return $Return;

};
Function Get-ForeignKeys {
   
    $sql = "select distinct FkName=fk.name
    , IsNotTrusted=is_not_trusted 
    from sys.foreign_keys fk
    inner join sys.tables t
    on t.object_id = fk.parent_object_id
    where t.name like '%sqlwatch%'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{FkName = $_.FkName; IsNotTrusted = $_.IsNotTrusted}};
    return $Return;    

};

Function Get-PrimaryKeys {
    
    $sql = "select PkName=name
    from sys.indexes pk
         where pk.is_primary_key = 1"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{PkName = $_.PkName}};
    return $Return;    

};

Function Get-SqlConfiguration {
    
    $sql = "
            select top 1 name='SqlServerUptimeHours',
            value=convert(varchar,datediff(hour,sqlserver_start_time,getdate()))
            from sys.dm_os_sys_info
            
            union all

            select name='SqlWatchActions', value=convert(varchar,count(*))
            from sqlwatch_config_action
            where action_enabled = 1
            and action_exec is not null
            
            union all

            select name='SqlAgentStatus', value=convert(varchar,[dbo].[ufn_sqlwatch_get_agent_status]())

            union all

            select name='AvailabiltyGroups', value=convert(varchar,count(*) )
            from sys.availability_groups

            union all

            select name='SqlWatchIndexHistograms', value=convert(varchar,count(*))
            from [dbo].[sqlwatch_config_include_index_histogram] 
            where object_name_pattern <> '%.dbo.table%'

            union all

            select name='sp_WhoIsActive', value= convert(varchar,case when sum(cnt) > 0 then 1 else 0 end)
            from (
                select cnt=count(*) 
                from sys.all_objects
                where name = 'sp_WhoIsActive'
                union all
                select cnt=count(*)
                from master.sys.all_objects
                where name = 'sp_WhoIsActive'
            ) t

            union all

            select name ='SqlWatchBaselines', value=convert(varchar,count(*))
            from dbo.sqlwatch_config_baseline

            union all

            select name ='SqlServerCollation',value=collation_name
            from sys.databases where name = 'tempdb'

            union all

            select name= 'SqlWatchCollation',value=collation_name
            from sys.databases where name = DB_NAME()

            union all

            select name ='UTCOffset', value=convert(varchar,datediff(hour,getutcdate(),getdate()))
        "
        $Return = @{};
        Invoke-SqlWatchCmd -Query $sql | ForEach-Object { $Return[$_.Name] = $_.value }
        return $Return ;
}
Function Get-DateTimeColumns {
    
    $sql="select [SqlWatchTable]=c.TABLE_SCHEMA + '.' + c.TABLE_NAME, [SqlWatchColumn]=c.COLUMN_NAME
    from INFORMATION_SCHEMA.COLUMNS c
    inner join INFORMATION_SCHEMA.TABLES t
        on t.TABLE_CATALOG = c.TABLE_CATALOG
        and t.TABLE_NAME = c.TABLE_NAME
        and t.TABLE_SCHEMA = c.TABLE_SCHEMA
    where t.TABLE_TYPE = 'BASE TABLE'         
    and c.DATA_TYPE LIKE '%time%'
    and t.TABLE_NAME like '%sqlwatch%'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{SqlWatchTable = $_.SqlWatchTable; SqlWatchColumn = $_.SqlWatchColumn;}};
    return $Return;    
};

Function Get-AllProcedures {

    $sql = "select ProcedureName=name 
    from sys.all_objects
	where is_ms_shipped = 0
    and type_desc = 'SQL_STORED_PROCEDURE'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ProcedureName = $_.ProcedureName}};
    return $Return;      
}

Function Get-AllViews {

    $sql = "select ViewName=name 
    from sys.all_objects
    where is_ms_shipped = 0
    and type_desc = 'VIEW'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ViewName = $_.ViewName}};
    return $Return;      
}

Function Get-AllTables {

    $sql = "select TableName=name 
    from sys.all_objects
    where is_ms_shipped = 0
    and type_desc = 'USER_TABLE'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName}};
    return $Return;      
}

Function Get-AllFunctions {

    $sql = "select FunctionName=name 
    from sys.all_objects
    where is_ms_shipped = 0
    and type_desc like '%FUNCTION'"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{FunctionName = $_.FunctionName}};
    return $Return;      
}

Function Get-AllParentObjects {
    
    $sql = "select ObjectName=name 
    from sys.all_objects
    where is_ms_shipped = 0
    and parent_object_id = 0"

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ObjectName = $_.ObjectName}};
    return $Return;        
};

Function Get-SqlWatchProcedures {
    
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

    $Return = @();
    Invoke-SqlWatchCmd -Query $sql | Foreach-Object {$Return += @{ProcedureName = $_.ProcedureName;}};
    return $Return;   
};

Function New-SqlWatchTestDatabase {
    
    $SqlWatchDatabaseTest = $global:SqlWatchDatabase + "_TEST"
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

    Invoke-Sqlcmd -ServerInstance $global:SqlInstance -Database master -Query $sql;

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
    end;"


    Invoke-Sqlcmd -ServerInstance $global:SqlInstance -Database $SqlWatchDatabaseTest -Query $sql;

    return $SqlWatchDatabaseTest;

};

Function New-SqlWatchTest {
    $sql = "insert into [dbo].[sqlwatch_pester_ref] (date,test)
    values (getutcdate(),'Test Start')"

    Invoke-Sqlcmd -ServerInstance $global:SqlInstance -Database $SqlWatchDatabaseTest -Query $sql;
    
}

Function New-HeadBlocker {

    $scriptBlock = {           
        param($SqlInstance , $SqlWatchDatabaseTest)
        Invoke-SqlCmd -ServerInstance $($SqlInstance) -Database $($SqlWatchDatabaseTest) -Query "
        begin tran
            select * from [dbo].[sqlwatch_pester_ref] with (tablock, holdlock, xlock)
            waitfor delay '00:00:25'
        commit tran
        "
    }
     
    $HeadBlocker = Start-Job -ScriptBlock $scriptBlock -ArgumentList $global:SqlInstance, $global:SqlWatchDatabaseTest
    Return $HeadBlocker
}

Function New-BlockedProcess {
            
    return Invoke-SqlCmd -ServerInstance $($global:SqlInstance) -Database $($global:SqlWatchDatabaseTest) -Query "select cnt=count(*) from [dbo].[sqlwatch_pester_ref]" 
}

Function Get-Test {
    return 1
};