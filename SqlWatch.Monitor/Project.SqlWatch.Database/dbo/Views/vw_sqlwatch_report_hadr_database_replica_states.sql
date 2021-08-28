CREATE VIEW [dbo].[vw_sqlwatch_report_hadr_database_replica_states]
WITH SCHEMABINDING AS

--https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-hadr-database-replica-states-transact-sql
--https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-availability-replicas-transact-sql
select 
	  [hadr_group_name]
	, [replica_server_name]
	, [availability_mode]
	, [availability_mode_desc] = case [availability_mode]
			when 0 then 'ASYNCHRONOUS_COMMIT'
			when 1 then 'SYNCHRONOUS_COMMIT'
			when 4 then 'CONFIGURATION_ONLY'
			else convert(varchar(max),[availability_mode]) end
	, [failover_mode]
	, [failover_mode_desc] = case [failover_mode]
			when 0 then 'AUTOMATIC'
			when 1 then 'MANUAL'
			else convert(varchar(max),[failover_mode]) end
	, [database_name]
	, [is_local]
	, [is_primary_replica]
	, [synchronization_state]
	, [synchronization_state_desc] = case [synchronization_state]
			when 0 then 'NOT SYNCHRONIZING'
			when 1 then 'SYNCHRONIZING'
			when 2 then 'SYNCHRONIZED'
			when 3 then 'REVERTING'
			when 4 then 'INITIALIZING'
			else convert(varchar(max),[synchronization_state]) end
	, [is_commit_participant]
	, [synchronization_health]
	, [synchronization_health_desc] = case [synchronization_health]
			when 0 then 'NOT_HEALTHY'
			when 1 then 'PARTIALLY_HEALTHY'
			when 2 then 'HEALTHY'
			else convert(varchar(max),[synchronization_health]) end
	, [database_state] 
	, [database_state_desc] = case [database_state]
			when 0 then 'ONLINE'
			when 1 then 'RESTORING'
			when 2 then 'RECOVERING'
			when 3 then 'RECOVERY_PENDING'
			when 4 then 'SUSPECT'
			when 5 then 'EMERGENCY'
			when 6 then 'OFFLINE'
			else convert(varchar(max),[database_state]) end
	, [is_suspended]
	, [suspend_reason] 
	, [suspend_reason_desc] = case [suspend_reason]
			when 0 then 'SUSPEND_FROM_USER'
			when 1 then 'SUSPEND_FROM_PARTNER'
			when 2 then 'SUSPEND_FROM_REDO'
			when 3 then 'SUSPEND_FROM_APPLY'
			when 4 then 'SUSPEND_FROM_CAPTURE'
			when 5 then 'SUSPEND_FROM_RESTART'
			when 6 then 'SUSPEND_FROM_UNDO'
			when 7 then 'SUSPEND_FROM_REVALIDATION'
			when 8 then 'SUSPEND_FROM_XRF_UPDATE'
			else convert(varchar(max),[suspend_reason]) end

	, [log_send_queue_size]
	, [log_send_rate]
	, [redo_queue_size]
	, [redo_rate]
	, [filestream_send_rate]
	, [secondary_lag_seconds]
	, [last_commit_time]
	, [snapshot_time]
	, rs.[sql_instance]
from [dbo].[sqlwatch_logger_dm_hadr_database_replica_states] rs;
--inner join dbo.sqlwatch_meta_database db
--on db.sqlwatch_database_id = rs.sqlwatch_database_id
--and db.sql_instance = rs.sql_instance