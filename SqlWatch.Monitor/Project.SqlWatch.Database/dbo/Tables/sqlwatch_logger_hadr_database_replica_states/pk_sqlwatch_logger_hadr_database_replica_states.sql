ALTER TABLE [dbo].[sqlwatch_logger_hadr_database_replica_states]
	ADD CONSTRAINT [pk_sqlwatch_logger_hadr_database_replica_states]
	PRIMARY KEY ([hadr_group_name],[replica_server_name],[database_name],[snapshot_time],[sql_instance],[snapshot_type_id])
	with (data_compression=page)
