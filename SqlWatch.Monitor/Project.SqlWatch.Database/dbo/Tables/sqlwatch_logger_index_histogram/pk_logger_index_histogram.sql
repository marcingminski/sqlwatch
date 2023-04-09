ALTER TABLE [dbo].[sqlwatch_logger_index_histogram]
	ADD CONSTRAINT [pk_logger_index_histogram]
	PRIMARY KEY CLUSTERED ([snapshot_time],[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [sqlwatch_stat_range_id], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)
