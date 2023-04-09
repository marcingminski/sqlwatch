ALTER TABLE [dbo].[sqlwatch_logger_xes_iosubsystem]
	ADD CONSTRAINT [pk_logger_performance_xes_iosubsystem]
	PRIMARY KEY CLUSTERED ([snapshot_time], [snapshot_type_id], [sql_instance], [event_time])
	WITH (DATA_COMPRESSION=PAGE)
