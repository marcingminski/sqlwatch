ALTER TABLE[dbo].[sqlwatch_logger_perf_os_wait_stats]
	ADD CONSTRAINT [pk_sql_perf_mon_wait_stats]
	PRIMARY KEY CLUSTERED ([snapshot_time] asc, [snapshot_type_id] asc, [sql_instance] asc, [wait_type_id] asc)
	WITH (DATA_COMPRESSION=PAGE)
