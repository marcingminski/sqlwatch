ALTER TABLE [dbo].[sqlwatch_logger_check_action]
	ADD CONSTRAINT [pk_sqlwatch_logger_check_action]
	PRIMARY KEY clustered ([snapshot_time], [sql_instance], [check_id], [snapshot_type_id], [action_id])
	with (data_compression=page)
