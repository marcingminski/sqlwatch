ALTER TABLE [dbo].[sqlwatch_logger_perf_os_process_memory]
	ADD CONSTRAINT [pk_sql_perf_mon_os_process_memory]
	PRIMARY KEY CLUSTERED ([snapshot_time], [snapshot_type_id], [sql_instance])
	WITH (DATA_COMPRESSION=PAGE)
