CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_agent_job_history]
AS


SET XACT_ABORT ON

declare @snapshot_time datetime
declare @snapshot_type_id smallint

set @snapshot_type_id = 16
set @snapshot_time = getdate()

insert into sqlwatch_logger_snapshot_header (snapshot_time, snapshot_type_id)
select @snapshot_time, @snapshot_type_id

declare @instance_id int
	 select @instance_id = isnull(max([sysjobhistory_instance_id]),0)
	 from [dbo].[sqlwatch_logger_agent_job_history]
	 where sql_instance = @@SERVERNAME

insert into [dbo].[sqlwatch_logger_agent_job_history] (sql_instance, sqlwatch_job_id, sqlwatch_job_step_id, sysjobhistory_instance_id, sysjobhistory_step_id,
	run_duration_s, run_date, run_status, snapshot_time, snapshot_type_id)
select sql_instance=@@SERVERNAME, mj.sqlwatch_job_id, sqlwatch_job_step_id, instance_id, step_id,
 run_duration_s = ((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + run_duration%100 + 31 )),
 run_date = msdb.dbo.agent_datetime(jh.run_date, jh.run_time),
 run_status,
 snapshot_time = @snapshot_time, 
 snapshot_type_id = @snapshot_type_id
from msdb.dbo.sysjobhistory jh
	inner join msdb.dbo.sysjobs sj
		on jh.job_id = sj.job_id
	inner join dbo.sqlwatch_meta_agent_job mj
		on mj.job_name = sj.name
		and mj.job_create_date = sj.date_created
		and mj.sql_instance = @@SERVERNAME
	inner join dbo.sqlwatch_meta_agent_job_step js
		on js.sql_instance = @@SERVERNAME
		and js.sqlwatch_job_id = mj.sqlwatch_job_id
		and js.step_name = jh.step_name
where instance_id > @instance_id