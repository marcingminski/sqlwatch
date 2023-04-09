create nonclustered index idx_sqlwatch_logger_perf_os_wait_stats_wait_type_id 
	on [dbo].[sqlwatch_logger_perf_os_wait_stats] ([sql_instance], [wait_type_id])
	with (data_compression=page)