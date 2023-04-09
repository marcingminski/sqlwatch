ALTER TABLE [dbo].[sqlwatch_logger_index_usage_stats]
	ADD CONSTRAINT [pk_index_usage_stats]
	PRIMARY KEY clustered ([snapshot_time], [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)
