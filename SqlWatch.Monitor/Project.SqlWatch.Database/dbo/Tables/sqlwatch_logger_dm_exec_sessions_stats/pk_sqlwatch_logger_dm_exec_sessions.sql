ALTER TABLE [dbo].[sqlwatch_logger_dm_exec_sessions_stats]
	ADD CONSTRAINT [pk_sqlwatch_logger_dm_exec_sessions]
	PRIMARY KEY clustered
	(
		[type] ASC,
		[snapshot_time] ASC,
		[snapshot_type_id] ASC,
		[sql_instance] ASC
	)
	with (data_compression=page)
