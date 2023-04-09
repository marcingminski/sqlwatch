create nonclustered index idx_sqlwatch_logger_perf_os_wait_stats_waiting_count_delta 
	on [dbo].[sqlwatch_logger_perf_os_wait_stats] ([waiting_tasks_count_delta]) include ([wait_time_ms_delta])
	with (data_compression=page)