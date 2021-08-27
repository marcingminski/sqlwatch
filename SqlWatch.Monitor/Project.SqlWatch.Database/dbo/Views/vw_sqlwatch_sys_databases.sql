CREATE VIEW [dbo].[vw_sqlwatch_sys_databases]
as

select 
	  sql_instance = @@SERVERNAME
	, [d].[name]
	, [d].[database_id]
	, [d].[create_date]
	, [d].[is_auto_close_on]
	, [d].[is_auto_shrink_on]
	, [d].[is_auto_update_stats_on]
	, [d].[user_access]
	, [d].[state]
	, [d].[snapshot_isolation_state] 
	, [d].[is_read_committed_snapshot_on] 
	, [d].[recovery_model] 
	, [d].[page_verify_option]
	--we use database_name and database_create_date across sqlwatch so having these available here makes it easier:
	, [database_name] = d.[name]
	, database_create_date = convert(datetime2(3),case when d.name = 'tempdb' then '1970-01-01 00:00:00.000' else [d].[create_date] end)
from sys.databases d

/*	remove these joins and related where clauses when building for SQL2008 */
/* https://github.com/marcingminski/sqlwatch/issues/108 */
left join sys.dm_hadr_availability_replica_states hars 
	on d.replica_id = hars.replica_id
left join sys.availability_replicas ar 
	on d.replica_id = ar.replica_id

where state_desc = 'ONLINE' --only online database

/* AG dbs */
and ( 
		--if part of AG include primary only
		(hars.role_desc = 'PRIMARY' OR hars.role_desc IS NULL)

		--OR if part of AG include secondary only when is readable
	or  (hars.role_desc = 'SECONDARY' AND ar.secondary_role_allow_connections_desc IN ('READ_ONLY','ALL'))
)
--exclude snapshots
and source_database_id is null;