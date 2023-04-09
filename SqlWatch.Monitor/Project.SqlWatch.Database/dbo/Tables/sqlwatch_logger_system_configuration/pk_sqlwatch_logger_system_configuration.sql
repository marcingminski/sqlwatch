ALTER TABLE [dbo].[sqlwatch_logger_system_configuration]
	ADD CONSTRAINT [pk_sqlwatch_logger_system_configuration]
	PRIMARY KEY CLUSTERED (sql_instance, sqlwatch_configuration_id, snapshot_time, snapshot_type_id)
	WITH (DATA_COMPRESSION=PAGE)
