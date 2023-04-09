ALTER TABLE [dbo].[sqlwatch_logger_report_action]
	ADD CONSTRAINT [pk_sqlwatch_logger_report_action_action]
	primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id], [report_id], [action_id]
	)
	WITH (DATA_COMPRESSION=PAGE)
