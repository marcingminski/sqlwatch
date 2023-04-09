create unique nonclustered index idx_sqlwatch_xes_iosubsystem_event_time
	on [dbo].[sqlwatch_logger_xes_iosubsystem] ([event_time], [sql_instance])
	with (data_compression=page)