ALTER TABLE [dbo].[sqlwatch_logger_perf_os_memory_clerks]
	ADD CONSTRAINT [pk_sql_perf_mon_os_memory_clerks]
	PRIMARY KEY CLUSTERED ([snapshot_time], [snapshot_type_id], [sql_instance], [sqlwatch_mem_clerk_id])
	WITH (DATA_COMPRESSION=PAGE)
