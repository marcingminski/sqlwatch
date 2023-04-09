ALTER TABLE [dbo].[sqlwatch_logger_snapshot_header]
	ADD CONSTRAINT [pk_snapshot]
	PRIMARY KEY CLUSTERED ([snapshot_time], [sql_instance], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)