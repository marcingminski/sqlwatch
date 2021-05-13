Function Get-SqlWatchTables {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }
    
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
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName }};
    return $Return;        
};

Function Get-SqlWatchTableKeys {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }

    $sql = "select TableName=schema_name(t.schema_id) + '.' +  t.[name], 
    PkName = pk.[name], FkName=fk.[name]
    from sys.tables t
    left join sys.indexes pk
        on t.object_id = pk.object_id 
        and pk.is_primary_key = 1
    left join sys.foreign_keys fk
        on fk.parent_object_id = t.object_id
    where t.name like '%sqlwatch%'";
    $Return = @();
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName; PkName = $_.PkName; FkName = $_.FkName}};
    return $Return;

};
Function Get-CheckConstraints {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }

    $sql = "select 
            TableName=t.name
        , ConstraintName = s.name
        , IsNotTrusted = s.is_not_trusted
    from sys.check_constraints s
    inner join sys.tables t
        on s.parent_object_id = t.object_id
    where t.name like '%sqlwatch%'";

    $Return = @();
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{TableName = $_.TableName; ConstraintName = $_.ConstraintName; IsNotTrusted = $_.IsNotTrusted}};
    return $Return;
};
Function Get-DefaultConstraints {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }

    $sql = "select distinct
        ConstraintName = df.name
    from sys.default_constraints df
    inner join sys.tables t
        on t.object_id = df.parent_object_id
        where t.name like '%sqlwatch%'";

    $Return = @();
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{ConstraintName = $_.ConstraintName}};
    return $Return;

};
Function Get-ForeignKeys {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }
    
    $sql = "select distinct FkName=fk.name
    , IsNotTrusted=is_not_trusted 
    from sys.foreign_keys fk
    inner join sys.tables t
    on t.object_id = fk.parent_object_id
    where t.name like '%sqlwatch%'"

    $Return = @();
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{FkName = $_.FkName; IsNotTrusted = $_.IsNotTrusted}};
    return $Return;    

};

Function Get-SqlConfiguration {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    } 
    
    $sql = "
        select top 1 name='SqlServerUptimeHours',
        value=datediff(hour,sqlserver_start_time,getdate())
        from sys.dm_os_sys_info
        
        union all

        select name='SqlWatchActions', value=count(*)
        from sqlwatch_config_action
        where action_enabled = 1
        and action_exec is not null
        
        union all

        select name='SqlAgentStatus', value=[dbo].[ufn_sqlwatch_get_agent_status]()

        union all

        select name='AvailabiltyGroups', value=count(*) 
        from sys.availability_groups

        union all

        select name='SqlWatchIndexHistograms', value=count(*)
        from [dbo].[sqlwatch_config_include_index_histogram] 
        where object_name_pattern <> '%.dbo.table%'

        union all

        select name='sp_WhoIsActive', value= convert(bit,case when sum(cnt) > 0 then 1 else 0 end)
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

        select name ='SqlWatchBaselines', value=count(*)
        from dbo.sqlwatch_config_baseline
        "
        $Return = @{};
        Invoke-SqlCmd @SqlCmdParams -Query $sql | ForEach-Object { $Return[$_.Name] = $_.value }
        return $Return ;
}
Function Get-DateTimeColumns {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    } 
    
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
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{SqlWatchTable = $_.SqlWatchTable; SqlWatchColumn = $_.SqlWatchColumn;}};
    return $Return;    
};

Function Get-SqlWatchProcedures {
    $SqlCmdParams = @{
        ServerInstance = $global:SqlInstance
        Database = $global:SqlWatchDatabase
        OutputSqlErrors = $global:OutputSqlErrors
    }
    
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
    Invoke-SqlCmd @SqlCmdParams -Query $sql | Foreach-Object {$Return += @{ProcedureName = $_.ProcedureName;}};
    return $Return;   
};

Function Get-Test {
    return 1
};