create unique nonclustered index idx_sqlwatch_xes_query_processing_event_time
	on [dbo].[sqlwatch_logger_xes_query_processing] ([event_time], [sql_instance])
	with (data_compression=page)