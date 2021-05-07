param(
    $SqlInstance,
    $SqlWatchDatabase
)


BeforeDiscovery {

    $SqlWatchDatabaseTest = "SQLWATCH_TEST"
   
    $sql = "select datediff(hour,sqlserver_start_time,getdate()) from sys.dm_os_sys_info"
    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database master -Query $sql
    $SqlUpHours = $result.Column1
    
    
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

    #SQLWATCH Procedures
    $sql = "select ProcName= s.name + '.' + p.name 
    from sys.procedures p
    inner join sys.schemas s
    on s.schema_id = p.schema_id
    where (
        p.name like 'usp_sqlwatch_internal_add%'
        or p.name like 'usp_sqlwatch_logger%'
        or p.name like 'usp_sqlwatch_internal_expand%'
        or p.name like 'usp_sqlwatch_internal_process%'
        )
    --not procedures with parameters as we dont know what param to pass
    and p.name not in (
        select distinct p1.name 
        from sys.procedures p1
        inner join sys.parameters r
            on r.object_id = p1.object_id
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

    $Procedure = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    ## SQLWATCH Config Tables
    $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
    from INFORMATION_SCHEMA.TABLES
    where TABLE_NAME not like '_DUMP_%'
    and TABLE_NAME like '%config%'
    and TABLE_NAME not like '%logger%'
    and TABLE_TYPE = 'BASE TABLE'";

    $ConfigTable = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
    from INFORMATION_SCHEMA.TABLES
    where TABLE_NAME not like '_DUMP_%'
    and TABLE_NAME like '%meta%'
    and TABLE_TYPE = 'BASE TABLE'";

    $MetaTable = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

    $sql = "select TableName=TABLE_SCHEMA + '.' + TABLE_NAME
    from INFORMATION_SCHEMA.TABLES
    where TABLE_NAME not like '_DUMP_%'
    and TABLE_NAME like '%logger%'
    and TABLE_TYPE = 'BASE TABLE'";

    $LoggerTable = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql    

    $sql = "select cnt=count(*) from sys.availability_groups"
    $AG = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sql

}

Describe 'Procedure Execution' {

    Context 'Procedure Should not Throw an error on the first run' {
        It "Procedure <_.ProcName> should not throw an error" -Foreach $Procedure {
            $sql = "exec $($_.ProcName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }

    Start-Sleep -s 1

    Context 'Procedure Should not Throw an error on the second run' {
        It "Procedure <_.ProcName> should not throw an error" -Foreach $Procedure {
            $sql = "exec $($_.ProcName);"
            { Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop } | Should -Not -Throw 
        }
    }    
}

Describe 'Config tables should not be empty' {
    Context 'Config tables should have rows' {
        It "Table <_.TableName> should have rows" -Foreach $ConfigTable {
            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }        
    }
    Context 'Meta tables should have rows' {
        It "Table <_.TableName> should have rows" -Foreach $MetaTable {
            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }        
    }
    Context 'Logger tables should have rows' {
        It "Table <_.TableName> should have rows" -Foreach $LoggerTable {
            if ($($_.TableName) -eq "dbo.sqlwatch_logger_hadr_database_replica_states") {
                Set-ItResult -Skip -Because "Availability Groups are not found"
            }
            if ($($_.TableName) -eq "dbo.sqlwatch_logger_xes_query_problems") {
                Set-ItResult -Skip -Because "this is not yet implemented"
            }
            
            $sql = "select row_count=count(*) from $($_.TableName)"
            (Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql -ErrorAction Stop).row_count | Should -BeGreaterThan 0
        }
    }
}

Describe 'Check Status should not be CHECK_ERROR' {

    #This can only run after we have run procedures that expand and create checks:
    $sql = "select CheckId=check_id, CheckName=check_name, CheckStatus=last_check_status from [dbo].[sqlwatch_meta_check]"
    $Check = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
        
    It 'Check [<_.CheckName>] has valid outcome (<_.CheckStatus>)' -ForEach $Check {
        $($_.CheckStatus) | Should -BeIn ("OK","WARNING","CRITICAL") -Because 'Checks must return an outcome, it should be either "OK", "WARNING", "CRITICAL"'
    }
}