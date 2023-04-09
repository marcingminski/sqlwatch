ALTER TABLE [dbo].[sqlwatch_logger_dm_exec_requests_stats]
	ADD CONSTRAINT [pk_sqlwatch_logger_dm_exec_requests]
	primary key clustered ([type], snapshot_time, sql_instance, snapshot_type_id)
	with (data_compression=page)
