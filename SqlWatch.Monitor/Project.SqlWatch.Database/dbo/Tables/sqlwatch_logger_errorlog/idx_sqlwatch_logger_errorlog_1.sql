create nonclustered index idx_sqlwatch_logger_errorlog_1 on [dbo].[sqlwatch_logger_errorlog] (
	keyword_id, log_type_id, sql_instance
	) include (log_date)
	with (data_compression=page)