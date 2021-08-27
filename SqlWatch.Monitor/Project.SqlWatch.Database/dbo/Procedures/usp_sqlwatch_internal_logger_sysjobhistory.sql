CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_sysjobhistory]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin
	set nocount on;

	insert into [dbo].[sqlwatch_logger_sysjobhistory] (
		sql_instance
		, sqlwatch_job_id
		, sqlwatch_job_step_id
		, sysjobhistory_instance_id
		, sysjobhistory_step_id
		, run_duration_s
		, run_date
		, run_status
		, snapshot_time
		, snapshot_type_id
		, [run_date_utc]
		)
	select 
		sql_instance=@sql_instance
		, mj.[sqlwatch_job_id]
		, js.sqlwatch_job_step_id
		, t.instance_id
		, t.step_id
		, run_duration_s = t.run_duration
		, t.run_date
		, t.run_status
		, snapshot_time = @snapshot_time
		, snapshot_type_id = @snapshot_type_id
		, t.[run_date_utc]
	
	from openxml (@xdoc, '/CollectionSnapshot/agent_job_history/row',1) 
		with (
			job_id uniqueidentifier,
			job_name nvarchar(128),
			job_create_date datetime2(3),
			instance_id int,
			step_id int,
			step_name nvarchar(128),
			run_datetime datetime2(3),
			run_duration real,
			run_date datetime2(3),
			[run_status] tinyint,
			[run_date_utc] datetime2(3)
		) t

		inner join dbo.sqlwatch_meta_agent_job mj
			on mj.job_name = t.job_name collate database_default
			and mj.job_create_date = t.job_create_date
			and mj.sql_instance = @sql_instance

		inner join dbo.sqlwatch_meta_agent_job_step js
			on js.sql_instance = mj.sql_instance
			and js.[sqlwatch_job_id] = mj.[sqlwatch_job_id]
			and js.step_name = t.step_name collate database_default

		/* make sure we are only getting new records from msdb history 
		   need to check performance over long time !!! */
		left join [dbo].[sqlwatch_logger_sysjobhistory] sh
			on sh.sql_instance = mj.sql_instance
			and sh.[sysjobhistory_instance_id] = t.instance_id
	
		where sh.[sysjobhistory_instance_id] is null;
end;