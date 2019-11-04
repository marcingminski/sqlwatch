CREATE PROCEDURE [dbo].[usp_sqlwatch_config_add_default_checks]
as
/*
-------------------------------------------------------------------------------------------------------------------
 usp_sqlwatch_config_add_default_checks

 This procedure will add pre-defined checks which include:
 --failed agent jobs alerts - check per job
 --disk utilisation and days left - check per disk
 --blocking processes
 --high cpu utilistaion

 These are example checks showing how the mechanism works, by all means add your own or modify default alerts.

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/
declare @checks as table(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[check_name] nvarchar(50) not null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) not null,
	[check_frequency_minutes] smallint null,
	[check_threshold_warning] varchar(100) null,
	[check_threshold_critical] varchar(100) null,
	[check_enabled] bit not null default 1,
	[target_id] smallint null,
	[trigger_enabled] bit not null default 1,
	[trigger_every_fail] bit not null default 0,
	[trigger_recovery] bit not null default 1,
	[trigger_repeat_period_minutes] smallint null
) 

--agent jobs:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Job failed: ' + aj.job_name
	,  [check_description] = 'Agent job ' + aj.job_name + ' jas failed in the past 60 minutes'
	,  [check_query] = 'select count (sysjobhistory_step_id)
  from [dbo].[vw_sqlwatch_report_fact_agent_job_history]
  where run_status = 0
  and [sql_instance] = ''' + aj.sql_instance + '''
  and [sqlwatch_job_id] = ' + convert(varchar(10),aj.[sqlwatch_job_id]) + '
  and report_time > dateadd(minute,-60,getutcdate())'
	,  [check_frequency_minutes] = 5
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>0'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 1 
	,  [trigger_recovery] = 1
	,  [trigger_repeat_period_minutes] = null
from [dbo].[sqlwatch_meta_agent_job] aj

--disks free percentage:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Disk Free %: ' + c.volume_name
	,  [check_description] = 'Disk ' + c.volume_name + ' has low free space. It may run out of space soon, depending on the growth.' 
	,  [check_query] = 'select [free_space_percentage]
  from [dbo].[vw_sqlwatch_report_dim_os_volume]
  where [sql_instance] = ''' + c.sql_instance + '''
  and [sqlwatch_volume_id] = ' + convert(varchar(10),c.sqlwatch_volume_id) + ''
	,  [check_frequency_minutes]  = 60
	,  [check_threshold_warning] = '<0.1'
	,  [check_threshold_critical] = '<0.05'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 0
	,  [trigger_recovery] = 1
	,  [trigger_repeat_period_minutes] = 1440
from [dbo].[vw_sqlwatch_report_dim_os_volume] c

--disks days until full:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Days left until disk full: ' + c.volume_name
	,  [check_description] = 'Disk ' + c.volume_name + ' will shortly be full. Please take action ASAP.'
	,  [check_query] = 'select [days_until_full]
  from [dbo].[vw_sqlwatch_report_dim_os_volume]
  where [sql_instance] = ''' + c.sql_instance + '''
  and [volume_bytes_growth] > 0
  and [sqlwatch_volume_id] = ' + convert(varchar(10),c.sqlwatch_volume_id) + ''
	,  [check_frequency_minutes] = 60
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '<7'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 1
	,  [trigger_repeat_period_minutes] = 1440
from [dbo].[vw_sqlwatch_report_dim_os_volume] c

--blocking chains:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Blocking detected in the past 5 minutes'
	,  [check_description] = 'In the last 5 minutes there has been blocked processes. Blocking means processes are stuck and unable to carry any work, could cause downtime or major outage.'
	,  [check_query] = 'select count (distinct [blocked_spid])
  FROM [dbo].[sqlwatch_logger_xes_blockers]
  where blocking_start_time > dateadd(minute,-5,getdate())'
	,  [check_frequency_minutes] = null
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>0'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 0
	,  [trigger_repeat_period_minutes] = null


--average CPU over the last 5 minutes:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Avergate CPU Utilistaion % (5m)'
	,  [check_description] = 'In the past 5 minutes, the average CPU utilistaion was higher than expected'
	,  [check_query] = 'select avg(cntr_value_calculated) 
from [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters]
where counter_name = ''Processor Time %''
and report_time > dateadd(minute,-5,getutcdate())'
	,  [check_frequency_minutes] = null
	,  [check_threshold_warning] = '>60'
	,  [check_threshold_critical] = '>80'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 1
	,  [trigger_repeat_period_minutes]  = null



--SQL Server uptime:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'SQL Instance Uptime'
	,  [check_description] = 'SQL Instance has been restared in the last 60 minutes.'
	,  [check_query] = 'select datediff(minute,sqlserver_start_time,getdate()) from sys.dm_os_sys_info'
	,  [check_frequency_minutes] = 15
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '<60'
	,  [check_enabled] = 1
	,  [target_id] = 1
	,  [trigger_enabled] = 1
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 0
	,  [trigger_repeat_period_minutes] = null


--Alert queue:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Alert Queue is high'
	,  [check_description] = 'There is a large number of items awaiting sending. This could indicate a problem with the sending mechansm.'
	,  [check_query] = 'select count(*) from [dbo].[sqlwatch_meta_alert_notify_queue] where send_status <> 2'
	,  [check_frequency_minutes] = 15
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>10'
	,  [check_enabled] = 1
	,  [target_id] = null
	,  [trigger_enabled] = null
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 0
	,  [trigger_repeat_period_minutes] = null

--Alert queue failures:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Alert Queue Failure is high'
	,  [check_description] = 'There is a large number of messages that failed to send. This could indicate a problem with the sending mechansm.'
	,  [check_query] = 'select count(*) from [dbo].[sqlwatch_meta_alert_notify_queue] where send_status = 2'
	,  [check_frequency_minutes] = 15
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>25'
	,  [check_enabled] = 1
	,  [target_id] = null
	,  [trigger_enabled] = null
	,  [trigger_every_fail] = 0
	,  [trigger_recovery]= 0
	,  [trigger_repeat_period_minutes] = null


merge [dbo].[sqlwatch_config_alert_check] as target
using @checks as source
on source.sql_instance = target.sql_instance
and source.check_name = target.check_name
and source.check_query = target.check_query
--when not matched by source then 
--	delete
when not matched by target then
	insert ([sql_instance],
			[check_name] ,
			[check_description] ,
			[check_query] ,
			[check_frequency_minutes],
			[check_threshold_warning],
			[check_threshold_critical],
			[check_enabled],
			[target_id],
			[trigger_enabled],
			[trigger_every_fail],
			[trigger_recovery],
			[trigger_repeat_period_minutes])
	values (source.[sql_instance],
			source.[check_name] ,
			source.[check_description] ,
			source.[check_query] ,
			source.[check_frequency_minutes],
			source.[check_threshold_warning],
			source.[check_threshold_critical],
			source.[check_enabled],
			source.[target_id],
			source.[trigger_enabled],
			source.[trigger_every_fail],
			source.[trigger_recovery],
			source.[trigger_repeat_period_minutes]);