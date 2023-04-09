create unique nonclustered index idx_sqlwatch_logger_xes_query_problems_1
	on [dbo].[sqlwatch_logger_xes_query_problems] ([event_time], [event_name], [event_hash], [occurence])
	with (data_compression=page)