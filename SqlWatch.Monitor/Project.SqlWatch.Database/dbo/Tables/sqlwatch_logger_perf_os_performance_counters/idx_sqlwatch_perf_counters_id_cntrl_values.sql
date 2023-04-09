CREATE INDEX [idx_sqlwatch_perf_counters_id_cntrl_values]
	ON [dbo].[sqlwatch_logger_perf_os_performance_counters] ([performance_counter_id],[sql_instance])
	INCLUDE ([cntr_value],[cntr_value_calculated])
	WITH (DATA_COMPRESSION=PAGE)
