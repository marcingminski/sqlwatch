CREATE VIEW [dbo].[vw_sqlwatch_report_fact_dm_db_missing_index_details]
with schemabinding
as

select 
	[mis].[sqlwatch_database_id]
	, [mis].[sqlwatch_table_id]
	, [mis].[sqlwatch_missing_index_id]
	, [mis].[sqlwatch_missing_index_stats_id]
	, [mis].[snapshot_time]
	, [mis].[last_user_seek]
	, [mis].[unique_compiles]
	, [mis].[user_seeks]
	, [mis].[user_scans]
	, [mis].[avg_total_user_cost]
	, [mis].[avg_user_impact]
	, [mis].[snapshot_type_id]
	, [mis].[sql_instance]
	, t.table_name
	, d.database_name
	, mi.equality_columns
	, mi.included_columns
	, mi.inequality_columns
	, mi.index_handle
	, mi.statement
	, index_id = database_name + '.' + table_name + ' (' + coalesce(equality_columns,inequality_columns) + ')'
from [dbo].[sqlwatch_logger_dm_db_missing_index_details] mis
  
  inner join [dbo].[sqlwatch_meta_index_missing] mi
  on mi.sql_instance = mis.sql_instance
  and mi.sqlwatch_missing_index_id = mis.sqlwatch_missing_index_id
  and mi.sqlwatch_table_id = mis.sqlwatch_table_id
  and mi.sqlwatch_database_id = mis.sqlwatch_database_id
  
  inner join dbo.sqlwatch_meta_table t
  on t.sql_instance = mis.sql_instance
  and t.sqlwatch_table_id = mi.sqlwatch_table_id
  and t.sqlwatch_database_id = mi.sqlwatch_database_id

  inner join dbo.sqlwatch_meta_database d
  on d.sqlwatch_database_id = mis.sqlwatch_database_id
  and d.sql_instance = mis.sql_instance;