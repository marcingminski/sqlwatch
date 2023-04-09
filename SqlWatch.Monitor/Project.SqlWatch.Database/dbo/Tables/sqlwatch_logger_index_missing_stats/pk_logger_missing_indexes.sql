ALTER TABLE [dbo].[sqlwatch_logger_index_missing_stats]
	ADD CONSTRAINT [pk_logger_missing_indexes]
	PRIMARY KEY CLUSTERED ([sql_instance], [snapshot_time], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_missing_index_id], [sqlwatch_missing_index_stats_id], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)
