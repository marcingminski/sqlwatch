CREATE TABLE [dbo].[sqlwatch_logger_hadr_database_replica_states]
(
	[hadr_group_name] varchar(128),
	[replica_server_name] varchar(128),
	[availability_mode] tinyint,
	[failover_mode] tinyint,
	[sqlwatch_database_id] smallint,
	[is_local] bit,
	[is_primary_replica] bit,
	[synchronization_state] tinyint,
	[is_commit_participant] bit,
	[synchronization_health] tinyint,
	[database_state] tinyint,
	[is_suspended] bit,
	[suspend_reason] bit,
	[log_send_queue_size] bit,
	[log_send_rate] real,
	[redo_queue_size] real,
	[redo_rate] real,
	[filestream_send_rate] real,
	[secondary_lag_seconds] real,
	[last_commit_time] datetime,
	[snapshot_type_id] tinyint not null,
	[snapshot_time] datetime2(0) not null,
	[sql_instance] varchar(32) not null ,

	constraint pk_sqlwatch_logger_hadr_database_replica_states
		primary key ([hadr_group_name],[replica_server_name],[sqlwatch_database_id],[snapshot_time],[sql_instance],[snapshot_type_id]),

	constraint fk_sqlwatch_logger_hadr_database_replica_states_header 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,

	constraint fk_sqlwatch_logger_hadr_database_replica_states_database
		foreign key ([sql_instance], [sqlwatch_database_id])
		references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id]) on delete cascade on update cascade

)