CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_sql_instance
	ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([sql_instance])
	INCLUDE ([performance_counter_id],[cntr_value_calculated_avg],[snapshot_time_offset])
	WITH (DATA_COMPRESSION=PAGE)