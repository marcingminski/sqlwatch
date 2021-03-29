CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_hadr_database_replica_states]
AS

declare @snapshot_type_id tinyint = 29
declare @date_snapshot_current datetime2(0)

--get snapshot header
exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @date_snapshot_current OUTPUT,
	@snapshot_type_id = @snapshot_type_id

insert into [dbo].[sqlwatch_logger_hadr_database_replica_states]
(
	[hadr_group_name] ,
	[replica_server_name] ,
	[availability_mode] ,
	[failover_mode] ,
	[sqlwatch_database_id] ,
	[is_local] ,
	[is_primary_replica] ,
	[synchronization_state] ,
	[is_commit_participant] ,
	[synchronization_health] ,
	[database_state] ,
	[is_suspended] ,
	[suspend_reason] ,
	[log_send_queue_size] ,
	[log_send_rate] ,
	[redo_queue_size] ,
	[redo_rate] ,
	[filestream_send_rate] ,
	[secondary_lag_seconds] ,
	[last_commit_time] ,
	[snapshot_type_id] ,
	[snapshot_time] ,
	[sql_instance] 
	)

select 
	 hadr_group_name = ag.name
	,ar.replica_server_name
	,ar.availability_mode
	,ar.failover_mode
	,db.sqlwatch_database_id
	,rs.is_local
	,[is_primary_replica] = null --rs.[is_primary_replica] --2014 onwards
	,rs.[synchronization_state]
	,rs.[is_commit_participant]
	,rs.[synchronization_health]
	,rs.[database_state]
	,rs.[is_suspended]
	,rs.[suspend_reason]
	,rs.[log_send_queue_size]
	,rs.[log_send_rate]
	,rs.[redo_queue_size]
	,rs.[redo_rate]
	,rs.[filestream_send_rate]
	,[secondary_lag_seconds] = null --rs.[secondary_lag_seconds] --2014 onwards
	,rs.[last_commit_time]
	,[snapshot_type_id]=@snapshot_type_id
	,[snapshot_time]=@date_snapshot_current
	,[sql_instance]=[dbo].[ufn_sqlwatch_get_servername]()
from sys.dm_hadr_database_replica_states rs
inner join sys.availability_replicas ar 
	on ar.group_id = rs.group_id
	and ar.replica_id = rs.replica_id
inner join sys.availability_groups ag
	on ag.group_id = rs.group_id
inner join dbo.vw_sqlwatch_sys_databases sdb
	on sdb.database_id = rs.database_id
inner join dbo.sqlwatch_meta_database db
	on db.database_name = sdb.name
	and db.database_create_date = sdb.create_date