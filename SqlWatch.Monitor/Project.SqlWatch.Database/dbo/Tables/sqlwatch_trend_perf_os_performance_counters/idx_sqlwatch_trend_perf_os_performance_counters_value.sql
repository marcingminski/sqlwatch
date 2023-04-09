CREATE NONCLUSTERED INDEX idx_sqlwatch_trend_perf_os_performance_counters_value
	ON [dbo].[sqlwatch_trend_perf_os_performance_counters] ([performance_counter_id],[sql_instance],[interval_minutes])
	INCLUDE ([cntr_value_calculated_avg])
	WITH (DATA_COMPRESSION=PAGE)