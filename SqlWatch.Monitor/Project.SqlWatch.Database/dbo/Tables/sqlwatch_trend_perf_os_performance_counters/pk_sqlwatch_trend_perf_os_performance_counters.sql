ALTER TABLE [dbo].[sqlwatch_trend_perf_os_performance_counters]
	ADD CONSTRAINT [pk_sqlwatch_trend_perf_os_performance_counters]
	PRIMARY KEY CLUSTERED ([snapshot_time] , [instance_name] , [sql_instance], [interval_minutes], [performance_counter_id]  )
	WITH (DATA_COMPRESSION=PAGE)