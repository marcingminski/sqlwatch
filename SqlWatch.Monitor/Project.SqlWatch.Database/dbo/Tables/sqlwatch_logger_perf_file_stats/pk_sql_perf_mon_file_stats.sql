ALTER TABLE [dbo].[sqlwatch_logger_perf_file_stats]
	ADD CONSTRAINT [pk_sql_perf_mon_file_stats]
	PRIMARY KEY CLUSTERED ([sql_instance], [snapshot_time], [sqlwatch_database_id], [sqlwatch_master_file_id], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)
