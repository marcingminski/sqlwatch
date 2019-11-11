CREATE PROCEDURE [dbo].[usp_sqlwatch_config_add_default_checks]
as
/*
-----------------------------------------------------------------------------------------------------------------
 usp_sqlwatch_config_add_default_checks

 This procedure will add pre-defined checks which include:
 failed agent jobs alerts - check per job
 disk utilisation and days left - check per disk
 blocking processes
 high cpu utilistaion

 These are example checks showing how the mechanism works, by all means add your own or modify default alerts.

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-----------------------------------------------------------------------------------------------------------------
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
	[action_id] smallint null,
	[action_enabled] bit not null default 1,
	[action_every_failure] bit not null default 0,
	[action_recovery] bit not null default 1,
	[action_repeat_period_minutes] smallint null,
	[action_hourly_limit] smallint,
	primary key clustered (
		[check_name]
	)
) 

--agent jobs:

insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Agent Jobs failed in the last 5 minutes' 
	,  [check_description] = 'An Agent job(s) has failed in the last 5 minutes.
In the last 5 minutes, the acount of failed agent jobs is greater than 0. 
Note that if this check is set to trigger on every failure, it will also trigger when the count decreases.
If the action has been set to trigger a report you should soon get another alert with list of failed job.'
	,  [check_query] = 'select count(*)
from msdb.dbo.sysjobhistory 
where msdb.dbo.agent_datetime(run_date, run_time) > dateadd(minute,-5,getdate())
and run_status = 0'
	,  [check_frequency_minutes] = 5
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>0'
	,  [check_enabled] = 1
	,  [action_id] = 6
	,  [action_enabled] = 1
	,  [action_every_failure] = 1 
	,  [action_recovery] = 0
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 10

insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Job failed: ' + aj.name
	,  [check_description] = 'Agent job ' + aj.name + ' has failed.
Please note that alerts for deleted jobs must also be deleted or disabled otherwise they will also raise alert.'
	,  [check_query] = 'select last_run_outcome= min(case when last_run_date = 0 /* job has not run yet, assume success otherwise it will fail trying to insert null */ then 1 else last_run_outcome end) 
from msdb.dbo.sysjobsteps js (nolock)
inner join msdb.dbo.sysjobs j (nolock)
on j.job_id = js.job_id
where j.name = ''' + aj.name + '''
group by j.name'
	,  [check_frequency_minutes] = null
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '<>1'
	,  [check_enabled] = 0
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 1 
	,  [action_recovery] = 1
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 2
from msdb.dbo.sysjobs aj
where aj.name like 'SQLWATCH%'



--disks free percentage:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Disk Free %: ' + c.volume_name
	,  [check_description] = 'Disk ' + c.volume_name + ' has low free space. It may run out of space soon, depending on the growth.' 
	,  [check_query] = 'select free_space_percentage
  from dbo.vw_sqlwatch_report_dim_os_volume
  where sql_instance = ''' + c.sql_instance + '''
  and sqlwatch_volume_id = ' + convert(varchar(10),c.sqlwatch_volume_id) + ''
	,  [check_frequency_minutes]  = 60
	,  [check_threshold_warning] = '<0.1'
	,  [check_threshold_critical] = '<0.05'
	,  [check_enabled] = 1
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 0
	,  [action_recovery] = 1
	,  [action_repeat_period_minutes] = 1440
	,  [action_hourly_limit] = 2
from [dbo].[vw_sqlwatch_report_dim_os_volume] c

--disks days until full:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Days left until disk full: ' + c.volume_name
	,  [check_description] = 'Disk ' + c.volume_name + ' will shortly be full. Please take action ASAP.'
	,  [check_query] = 'select days_until_full
  from dbo.vw_sqlwatch_report_dim_os_volume
  where sql_instance = ''' + c.sql_instance + '''
  and volume_bytes_growth > 0
  and sqlwatch_volume_id = ' + convert(varchar(10),c.sqlwatch_volume_id) + ''
	,  [check_frequency_minutes] = 60
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '<7'
	,  [check_enabled] = 1
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 0
	,  [action_recovery]= 1
	,  [action_repeat_period_minutes] = 1440
	,  [action_hourly_limit] = 2
from [dbo].[vw_sqlwatch_report_dim_os_volume] c

--blocking chains:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Blocking detected in the last 5 minutes'
	,  [check_description] = 'In the last 5 minutes there has been blocked processes. Blocking means processes are stuck and unable to carry any work, could cause downtime or major outage.'
	,  [check_query] = 'select count (distinct blocked_spid)
  FROM dbo.sqlwatch_logger_xes_blockers
  where blocking_start_time > dateadd(minute,-5,getdate())'
	,  [check_frequency_minutes] = 5
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>0'
	,  [check_enabled] = 1
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 0
	,  [notify_recovery]= 0
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 10

--average CPU over the last 5 minutes:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Avergate CPU Utilistaion % in the last 5 minutes'
	,  [check_description] = 'In the past 5 minutes, the average CPU utilistaion was higher than expected'
	,  [check_query] = 'select avg(cntr_value_calculated) 
from dbo.vw_sqlwatch_report_fact_perf_os_performance_counters
where counter_name = ''Processor Time %''
and report_time > dateadd(minute,-5,getutcdate())'
	,  [check_frequency_minutes] = 5
	,  [check_threshold_warning] = '>60'
	,  [check_threshold_critical] = '>80'
	,  [check_enabled] = 1
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 0
	,  [notify_recovery]= 1
	,  [action_repeat_period_minutes]  = null
	,  [action_hourly_limit] = 6


--SQL Server uptime:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'SQL Instance Uptime'
	,  [check_description] = 'SQL Instance has been restared in the last 60 minutes.'
	,  [check_query] = 'select datediff(minute,sqlserver_start_time,getdate()) from sys.dm_os_sys_info'
	,  [check_frequency_minutes] = 10
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '<60'
	,  [check_enabled] = 1
	,  [action_id] = 1
	,  [action_enabled] = 1
	,  [action_every_failure] = 0
	,  [notify_recovery]= 0
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 2


--Alert queue:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Delivery Queue is high'
	,  [check_description] = 'There is a large number of items awaiting delivery or sending. This could indicate a problem with the sending mechanism.
Note that in this context, the succesful delivery means that the item was succesfuly delievered to the desired target, for example sp_send_dbmail.
The second part of the process i.e. delivery of the actual mail is out of hand and relies purely on third party infrastructure.'
	,  [check_query] = 'select count(*) from dbo.sqlwatch_meta_action_queue where exec_status <> 2'
	,  [check_frequency_minutes] = 15
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>10'
	,  [check_enabled] = 1
	,  [action_id] = null
	,  [action_enabled] = 0
	,  [action_every_failure] = 0
	,  [notify_recovery]= 0
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 2

--Alert queue failures:
insert into @checks
select [sql_instance] = @@SERVERNAME
	,  [check_name] = 'Delivery Queue Failure is high'
	,  [check_description] = 'There is a large number of items that could not be delivered. This could indicate a problem with the sending mechanism.
Note that in this context, the succesful delivery means that the item was succesfuly delievered to the desired target, for example sp_send_dbmail.
The second part of the process i.e. delivery of the actual mail is out of hand and relies purely on third party infrastructure.'
	,  [check_query] = 'select count(*) from dbo.sqlwatch_meta_action_queue where exec_status = 2'
	,  [check_frequency_minutes] = 15
	,  [check_threshold_warning] = null
	,  [check_threshold_critical] = '>25'
	,  [check_enabled] = 1
	,  [action_id] = null
	,  [action_enabled] = 0
	,  [action_every_failure] = 0
	,  [notify_recovery]= 0
	,  [action_repeat_period_minutes] = null
	,  [action_hourly_limit] = 2


merge [dbo].[sqlwatch_config_check] as target
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
			[check_enabled]
			)
	values (source.[sql_instance],
			source.[check_name] ,
			source.[check_description] ,
			source.[check_query] ,
			source.[check_frequency_minutes],
			source.[check_threshold_warning],
			source.[check_threshold_critical],
			source.[check_enabled]
			);


merge [dbo].[sqlwatch_config_check_action] as target
using (
	select 
	  c.[sql_instance]
	, cc.check_id
	, [action_id]
	, [action_enabled]
	, [action_every_failure]
	, [action_recovery]
	, [action_repeat_period_minutes] 
	, [action_hourly_limit]
from @checks c
inner join [dbo].[sqlwatch_config_check] cc
	on cc.sql_instance = c.sql_instance
	and cc.check_name = c.check_name
	and cc.check_description = c.check_description
	and cc.check_query = c.check_query

	where c.action_enabled = 1
	) as source
on source.sql_instance = target.sql_instance
	and source.check_id = target.check_id
	and source.action_id = target.action_id

when not matched then
	insert ([sql_instance]
	, [check_id]
	, [action_id]
	, [action_every_failure]
	, [action_recovery]
	, [action_repeat_period_minutes]
	, [action_template_id]
	, [action_hourly_limit])
	values (
	  source.[sql_instance]
	, source.check_id
	, source.[action_id]
	, source.[action_every_failure]
	, source.[action_recovery]
	, source.[action_repeat_period_minutes] 
	, 1
	, source.[action_hourly_limit]
	);