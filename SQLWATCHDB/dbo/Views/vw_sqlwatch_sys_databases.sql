CREATE VIEW [dbo].[vw_sqlwatch_sys_databases]
as

select 
	  sql_instance = @@SERVERNAME
	, [d].[name]
	, [d].[database_id]
	, [d].[create_date]
from sys.databases d

/* https://github.com/marcingminski/sqlwatch/issues/108 */
left join sys.dm_hadr_availability_replica_states hars 
	on d.replica_id = hars.replica_id
left join sys.availability_replicas ar 
	on d.replica_id = ar.replica_id

where database_id > 4 --exclude system databases

and state_desc = 'ONLINE' --only online database

/* AG dbs */
and ( 
		--if part of AG include primary only
		(hars.role_desc = 'PRIMARY' OR hars.role_desc IS NULL)

		--OR if part of AG include secondary only when is readable
	or  (hars.role_desc = 'SECONDARY' AND ar.secondary_role_allow_connections_desc IN ('READ_ONLY','ALL'))
)
and [name] not like '%ReportServer%' --exclude SSRS database
and source_database_id is null --exclude snapshots
