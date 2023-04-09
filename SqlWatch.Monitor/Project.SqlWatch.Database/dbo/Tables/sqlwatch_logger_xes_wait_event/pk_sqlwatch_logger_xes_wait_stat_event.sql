ALTER TABLE [dbo].[sqlwatch_logger_xes_wait_event]
	ADD CONSTRAINT [pk_sqlwatch_logger_xes_wait_stat_event]
	PRIMARY KEY CLUSTERED (event_time, wait_type_id, session_id, [sql_instance], [snapshot_time], [snapshot_type_id] , activity_id)
	WITH (DATA_COMPRESSION=PAGE)