create nonclustered index idx_sqlwatch_logger_agent_job_history_run_date
	on dbo.sqlwatch_logger_agent_job_history (run_date)
	with (data_compression=page)