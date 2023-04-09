ALTER TABLE [dbo].[sqlwatch_logger_xes_query_processing]
	ADD CONSTRAINT [pk_logger_xe_query_processing]
	PRIMARY KEY CLUSTERED ([snapshot_time], [snapshot_type_id], [sql_instance], [event_time])
	WITH (DATA_COMPRESSION=PAGE)
