ALTER TABLE [dbo].[sqlwatch_logger_check]
	ADD CONSTRAINT [pk_sqlwatch_logger_check]
	PRIMARY KEY CLUSTERED (snapshot_time, sql_instance, check_id, snapshot_type_id)
	WITH (DATA_COMPRESSION=PAGE)
