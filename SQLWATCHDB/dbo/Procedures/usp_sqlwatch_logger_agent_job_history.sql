CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_agent_job_history]
AS


SET XACT_ABORT ON

declare @snapshot_time datetime
declare @snapshot_type_id smallint

set @snapshot_type_id = 16
set @snapshot_time = getdate()

insert into sqlwatch_logger_snapshot_header (snapshot_time, snapshot_type_id)
select @snapshot_time, @snapshot_type_id

insert into [dbo].[sqlwatch_logger_agent_job_history] (sql_instance, sqlwatch_job_id, sqlwatch_job_step_id, sysjobhistory_instance_id, sysjobhistory_step_id,
	run_duration_s, run_date, run_status, snapshot_time, snapshot_type_id)
select sql_instance=@@SERVERNAME, mj.sqlwatch_job_id, js.sqlwatch_job_step_id, instance_id, step_id,
 run_duration_s = ((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + run_duration%100 + 31 )),
 run_date = msdb.dbo.agent_datetime(jh.run_date, jh.run_time),
 jh.run_status,
 snapshot_time = @snapshot_time, 
 snapshot_type_id = @snapshot_type_id

from msdb.dbo.sysjobhistory jh

	inner join msdb.dbo.sysjobs sj
		on jh.job_id = sj.job_id

	inner join dbo.sqlwatch_meta_agent_job mj
		on mj.job_name = sj.name collate database_default
		and mj.job_create_date = sj.date_created
		and mj.sql_instance = @@SERVERNAME

	inner join dbo.sqlwatch_meta_agent_job_step js
		on js.sql_instance = mj.sql_instance
		and js.sqlwatch_job_id = mj.sqlwatch_job_id
		and js.step_name = jh.step_name collate database_default

	/* make sure we are only getting new records from msdb history 
	   need to check performnace over long time !!! */
	left join [dbo].[sqlwatch_logger_agent_job_history] sh
		on sh.sql_instance = mj.sql_instance
		and sh.[sysjobhistory_instance_id] = jh.instance_id
	
	where sh.[sysjobhistory_instance_id] is null
