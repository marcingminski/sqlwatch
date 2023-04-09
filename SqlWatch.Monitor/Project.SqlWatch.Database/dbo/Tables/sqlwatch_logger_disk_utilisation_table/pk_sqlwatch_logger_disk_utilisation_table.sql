ALTER TABLE [dbo].[sqlwatch_logger_disk_utilisation_table]
	ADD CONSTRAINT [pk_sqlwatch_logger_disk_utilisation_table]
	PRIMARY KEY CLUSTERED ([snapshot_time], [sql_instance], [snapshot_type_id], sqlwatch_database_id, sqlwatch_table_id)
	WITH (DATA_COMPRESSION=PAGE)
