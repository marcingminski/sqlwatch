ALTER TABLE [dbo].[sqlwatch_logger_perf_procedure_stats]
	ADD CONSTRAINT [pk_sqlwatch_logger_perf_procedure_stats]
	PRIMARY KEY CLUSTERED ([sql_instance], [sqlwatch_database_id], [sqlwatch_procedure_id], [snapshot_time], [snapshot_type_id], [cached_time])
	WITH (DATA_COMPRESSION=PAGE)
