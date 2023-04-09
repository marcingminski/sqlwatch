ALTER TABLE [dbo].[sqlwatch_logger_perf_os_performance_counters]
	ADD CONSTRAINT [pk_sql_perf_mon_perf_counters]
	PRIMARY KEY CLUSTERED ([snapshot_time] asc, [snapshot_type_id],[sql_instance], [performance_counter_id] asc, [instance_name] asc)
	WITH (DATA_COMPRESSION=PAGE)
