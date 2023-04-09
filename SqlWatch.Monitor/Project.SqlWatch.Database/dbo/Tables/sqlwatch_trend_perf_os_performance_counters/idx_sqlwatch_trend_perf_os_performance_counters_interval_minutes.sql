CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_interval_minutes
	ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([interval_minutes])
	INCLUDE ([performance_counter_id],[instance_name],[sql_instance],[snapshot_time])
	WITH (DATA_COMPRESSION=PAGE)