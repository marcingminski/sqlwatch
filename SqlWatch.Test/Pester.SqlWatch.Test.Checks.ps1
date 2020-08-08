$SqlInstance = "SQL-1";
$SqlWatchDatabase = "SQLWATCH";

$Checks = @() #thanks Rob https://sqldbawithabeard.com/2017/11/28/2-ways-to-loop-through-collections-in-pester/

$Checks = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query "select check_id, check_name from [dbo].[sqlwatch_config_check]"

$TestCases = @();

$Checks.ForEach{$TestCases += @{check_name = $_.check_name }}

Describe 'Test checks execution mechanism' {

  It 'Number of times check [<check_name>] has returned ERROR' -TestCases $TestCases {

    Param($check_name)
    $sql = "select count(*) from [dbo].[sqlwatch_config_check] cc left join [dbo].[sqlwatch_logger_check] lc on cc.check_id = lc.check_id where cc.check_name = '$($check_name)' and lc.check_status like '%ERROR%'"

    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
    $result.Column1 | Should -Be 0 
  }

  It 'Check [<check_name>] has a valid outcome' -TestCases $TestCases {
    
    Param($check_name) 
    $sql = "select count(*) from [dbo].[sqlwatch_meta_check] where check_name = '$($check_name)' and last_check_status = null"

    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
    $result.Column1 | Should -Be 0 
      
  }

  It 'Check [<check_name>] must respect execution frequency' -TestCases $TestCases {
     
    Param($check_name) 
    $sql = "select check_frequency_minutes from [dbo].[sqlwatch_config_check] where check_name = '$($check_name)' and check_frequency_minutes is not null"
    $check_frequency_minutes = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql


    $sql = ";with cte_rn as (
	select cc.check_id, lc.snapshot_time, RN=ROW_NUMBER() over (partition by cc.check_id order by lc.snapshot_time)
	from [dbo].[sqlwatch_logger_check] lc
	inner join dbo.sqlwatch_config_check cc
		on lc.check_id = cc.check_id
	where snapshot_time > dateadd(hour,-24,getutcdate())
    and cc.check_name = '$($check_name)'
)
select
	min_check_frequency_minutes_calculated=min(datediff(minute,c1.snapshot_time,c2.snapshot_time))
from cte_rn c1
left join cte_rn c2
	on c1.check_id = c2.check_id
	and c1.RN = c2.RN -1
group by c1.check_id
"

    $result = Invoke-SqlCmd -ServerInstance $SqlInstance -Database $SqlWatchDatabase -Query $sql
    $result.min_check_frequency_minutes_calculated | Should -Be $check_frequency_minutes.check_frequency_minutes
      
  }

}