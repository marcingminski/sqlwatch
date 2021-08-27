CREATE VIEW [dbo].[vw_sqlwatch_report_fact_dm_exec_requests_long_requests]
with schemabinding
as

select 
	snapshot_time
	,[session_id]
	,[database_name]
	,[cpu_time]
	,[physical_reads]
	,[logical_reads]
	,[writes]
	,[spills]
	,[username]
	,[client_hostname]
	,[client_app_name]
	,[duration_ms]
	,sql_text = sql_statement_sample
	,lr.sql_instance
from [dbo].[sqlwatch_logger_dm_exec_requests_long_requests] lr

	inner join [dbo].[sqlwatch_meta_sql_query] q
		on q.sql_instance = lr.sql_instance
		and q.sqlwatch_database_id = q.sqlwatch_database_id
		and q.query_hash = lr.query_hash

	inner join dbo.sqlwatch_meta_database db
		on db.sqlwatch_database_id = lr.sqlwatch_database_id
		and db.sql_instance = lr.sql_instance

	inner join dbo.sqlwatch_meta_procedure p
		on p.sql_instance = lr.sql_instance
		and p.sqlwatch_database_id = lr.sqlwatch_database_id
		and p.sqlwatch_procedure_id = q.sqlwatch_procedure_id;