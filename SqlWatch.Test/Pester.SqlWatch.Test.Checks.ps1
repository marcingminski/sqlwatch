param(
    $SqlInstance,
    $SqlWatchDatabase,
    $MinSqlUpHours = 4
)

$sql = "select datediff(hour,sqlserver_start_time,getdate()) from sys.dm_os_sys_info"
$result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
$SqlUpHours = $result.Column1 #| Should -BeGreaterThan 4 -Because 'Recently restarted Sql Instance may not provide accurate test results'

$Checks = @(); #thanks Rob https://sqldbawithabeard.com/2017/11/28/2-ways-to-loop-through-collections-in-pester/
$Checks = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query "select check_id, check_name from [dbo].[sqlwatch_config_check]"

$TestCases = @();
$Checks.ForEach{$TestCases += @{check_name = $_.check_name }}

Describe 'Failed Checks' {

    Context "Checking for checks that have failed to execute with the CHECK_ERROR outcome" {
    
        It 'Check [<check_name>] executions should never return status of CHECK ERROR' -TestCases $TestCases {

            Param($check_name)

            if ($SqlUpHours -lt $MinSqlUpHours) {

                It -Skip "SQL Server has recently been restared. For accureate results, please allow minimum of 6 hours before running these tests."

            } else {

                $sql = "declare @starttime datetime; 
    
                select @starttime=sqlserver_start_time 
                from sys.dm_os_sys_info
    
                select count(*) 
                    from [dbo].[sqlwatch_config_check] cc 
                    left join [dbo].[sqlwatch_logger_check] lc 
                        on cc.check_id = lc.check_id 
                    where snapshot_time > dateadd(hour,-48,getutcdate()) 
                    and cc.check_name = '$($check_name)' 
                    and lc.check_status like '%ERROR%'
                    --skip records after restart as Perf counters will be empty right after restart.
                    and lc.snapshot_time > dateadd(minute,2,@starttime)
                    "

                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
                $result.Column1 | Should -Be 0 -Because 'The check results should be "OK", "WARNING" or "CRITICAL". However, checks that fail to execute or return value that is out of bound, will return "CHECK ERROR" status.'

            }
        }
    }

    Context "Checking if checks have outcome" {
    
      It 'Check [<check_name>] should have an outcome' -TestCases $TestCases {
    

        Param($check_name) 

        if ($SqlUpHours -lt $MinSqlUpHours) {

            It -Skip "SQL Server has recently been restared. For accureate results, please allow minimum of 6 hours before running these tests."

        } else {

            $sql = "select last_check_status from [dbo].[sqlwatch_meta_check] where check_name = '$($check_name)'"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
            $result.last_check_status | Should -BeIn ("OK","WARNING","CRITICAL","CHECK ERROR") -Because 'Checks must return an outcome, it should be either "OK", "WARNING", "CRITICAL" or "CHECK_ERROR"'

        }
      
      }

    }

    Context "Checking for checks that do not respect the execution frequency parameter " {

         It 'Check [<check_name>] should respect execution frequency setting' -TestCases $TestCases {
     
            Param($check_name) 

            if ($SqlUpHours -lt $MinSqlUpHours) {

                It -Skip "SQL Server has recently been restared. For accureate results, please allow minimum of 6 hours before running these tests."

            } else {

                $sql = "select check_frequency_minutes=isnull(check_frequency_minutes,1) from [dbo].[sqlwatch_config_check] where check_name = '$($check_name)'"
                $check_frequency_minutes = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql

                $sql = "select cc.check_id, lc.snapshot_time, RN=ROW_NUMBER() over (partition by cc.check_id order by lc.snapshot_time)
            into #t
            from [dbo].[sqlwatch_logger_check] lc
            inner join dbo.sqlwatch_config_check cc
	            on lc.check_id = cc.check_id
            where snapshot_time > dateadd(hour,-48,getutcdate())
            and cc.check_name = '$($check_name)'

            create clustered index icx_tmp_t on #t (snapshot_time)

            select
	            min_check_frequency_minutes_calculated=min(datediff(minute,c1.snapshot_time,c2.snapshot_time))
            from #t c1
            left join #t c2
	            on c1.check_id = c2.check_id
	            and c1.RN = c2.RN -1
            "
                $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
                $result.min_check_frequency_minutes_calculated | Should -Be $check_frequency_minutes.check_frequency_minutes -Because 'The agent job that invokes the check engine runs every 1 minute but not all checks should run every 1 minute. There is a [check_frequency_minutes] column that tells us how often each check should run. This value must be respected otherwise all checks will run every 1 minute which will create additional load on the server'

            }
          }
    }
}

$TimeFields = @();
$TimeFields = "select column=TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS where DATA_TYPE LIKE '%time%'"

$TestCases = @();
$TimeFields.ForEach{$TestCases += @{column = $_.column}}

Describe 'Test database design' {

    $sql = "select datediff(hour,getutcdate(),getdate())"
    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

    if ($result.Column1 -ge 0) {
        It -Skip "The server must be in a time zone behind the UTC time zone in order to validate what time values are being written. This will allow us to assume that if the written value is in the future, the value is Not a UTC zone.";
    } else {
        It 'Datetime values in <column> should be UTC' -TestCases $TestCases {
            Param($column)
        
            $sql = "select LOCAL_TIME=GETDATE(), UTC_TIME=GETUTCDATE(), TABLE_NAME,COLUMN_NAME 
            from INFORMATION_SCHEMA.COLUMNS 
            where TABLE_SCHEMA + '.' + TABLE_NAME + '.' + COLUMN_NAME = '$($column)'"

            $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql;

            $sql = "select top 1 datediff(hour,GETUTCDATE(),$($result.COLUMN_NAME)) from [$($result.$TABLE_NAME)] order by $($result.COLUMN_NAME) desc";
            $result.Column1 | should -Not -BeGreaterThan 0 'Values in the future indicate incorrect time zone'    
        }
    }
}