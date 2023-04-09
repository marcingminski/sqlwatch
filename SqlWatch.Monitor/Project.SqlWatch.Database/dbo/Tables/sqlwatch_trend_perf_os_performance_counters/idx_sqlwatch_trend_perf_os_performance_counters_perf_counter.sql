CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_perf_counter
	ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([performance_counter_id],[sql_instance])
	INCLUDE ([cntr_value_calculated_avg],[snapshot_time_offset])
	WITH (DATA_COMPRESSION=PAGE)