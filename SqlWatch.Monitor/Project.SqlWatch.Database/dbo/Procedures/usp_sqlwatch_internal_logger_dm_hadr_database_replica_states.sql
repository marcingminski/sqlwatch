CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_hadr_database_replica_states]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin
	set nocount on;
	
	insert into [dbo].[sqlwatch_logger_dm_hadr_database_replica_states] (
		[hadr_group_name] 
		,[replica_server_name] 
		,[availability_mode] 
		,[failover_mode] 
		,[database_name] 
		,[is_local] 
		,[is_primary_replica] 
		,[synchronization_state] 
		,[is_commit_participant] 
		,[synchronization_health]
		,[database_state] 
		,[is_suspended] 
		,[suspend_reason] 
		,[log_send_queue_size] 
		,[log_send_rate] 
		,[redo_queue_size] 
		,[redo_rate] 
		,[filestream_send_rate] 
		,[secondary_lag_seconds]
		,[last_commit_time] 
		,[snapshot_time]
		,[snapshot_type_id] 
		,[sql_instance] 
	)
	select
		[hadr_group_name] 
		,[replica_server_name] 
		,[availability_mode] 
		,[failover_mode] 
		,[database_name] 
		,[is_local] 
		,[is_primary_replica] 
		,[synchronization_state] 
		,[is_commit_participant] 
		,[synchronization_health]
		,[database_state] 
		,[is_suspended] 
		,[suspend_reason] 
		,[log_send_queue_size] 
		,[log_send_rate] 
		,[redo_queue_size] 
		,[redo_rate] 
		,[filestream_send_rate] 
		,[secondary_lag_seconds]
		,[last_commit_time] 
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from openxml (@xdoc, '/CollectionSnapshot/dm_hadr_database_replica_states/row',1) 
		with (
			[hadr_group_name] nvarchar(128),
			[replica_server_name] nvarchar(128),
			[availability_mode] tinyint,
			[failover_mode] tinyint,
			[database_name] nvarchar(128),
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
			[last_commit_time] datetime2(3)
		)	
	option (keep plan);
end;