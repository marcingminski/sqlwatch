ALTER TABLE [dbo].[sqlwatch_logger_disk_utilisation_database]
	ADD CONSTRAINT [PK_logger_disk_util_database]
	PRIMARY KEY CLUSTERED ([snapshot_time],[snapshot_type_id],[sql_instance], [sqlwatch_database_id])
	WITH (DATA_COMPRESSION=PAGE)
