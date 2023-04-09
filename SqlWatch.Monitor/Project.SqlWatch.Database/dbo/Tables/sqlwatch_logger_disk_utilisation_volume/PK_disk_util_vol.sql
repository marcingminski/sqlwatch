ALTER TABLE [dbo].[sqlwatch_logger_disk_utilisation_volume]
	ADD CONSTRAINT [PK_disk_util_vol]
	PRIMARY KEY CLUSTERED (snapshot_time, [snapshot_type_id], [sql_instance], [sqlwatch_volume_id])
	WITH (DATA_COMPRESSION=PAGE)
