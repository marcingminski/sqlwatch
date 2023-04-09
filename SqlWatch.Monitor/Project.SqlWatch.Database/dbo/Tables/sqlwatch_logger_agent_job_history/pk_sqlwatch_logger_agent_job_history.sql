ALTER TABLE [dbo].[sqlwatch_logger_agent_job_history]
	ADD CONSTRAINT [pk_sqlwatch_logger_agent_job_history]
	PRIMARY KEY CLUSTERED ([sql_instance], [snapshot_time], [sqlwatch_job_id], [sqlwatch_job_step_id], [sysjobhistory_instance_id], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)
