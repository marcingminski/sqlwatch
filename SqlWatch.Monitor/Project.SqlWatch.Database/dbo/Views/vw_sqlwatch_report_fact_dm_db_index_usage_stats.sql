CREATE VIEW [dbo].[vw_sqlwatch_report_fact_dm_db_index_usage_stats]
with schemabinding
as

select 
	[ius].[sqlwatch_database_id]
	, [ius].[sqlwatch_table_id]
	, [ius].[sqlwatch_index_id]
	, [ius].[used_pages_count]
	, [ius].[user_seeks]
	, [ius].[user_scans]
	, [ius].[user_lookups]
	, [ius].[user_updates]
	, [ius].[last_user_seek]
	, [ius].[last_user_scan]
	, [ius].[last_user_lookup]
	, [ius].[last_user_update]
	, [ius].[stats_date]
	, [ius].[snapshot_time]
	, [ius].[snapshot_type_id]
	, [ius].[index_disabled]
	, [ius].[sql_instance]
	, [ius].[partition_id]
	, [ius].[used_pages_count_delta]
	, [ius].[user_seeks_delta]
	, [ius].[user_scans_delta]
	, [ius].[user_updates_delta]
	, [ius].[delta_seconds]
	, [ius].[user_lookups_delta]
	, [ius].[partition_count]
	, [ius].[partition_count_delta]
	, i.index_name
	, t.table_name
	, d.database_name
from [dbo].[sqlwatch_logger_dm_db_index_usage_stats] ius

inner join dbo.sqlwatch_meta_index i
	on i.sql_instance = ius.sql_instance
	and i.sqlwatch_index_id = ius.sqlwatch_index_id
	and i.sqlwatch_table_id = ius.sqlwatch_table_id
	and i.sqlwatch_database_id = ius.sqlwatch_database_id

inner join dbo.sqlwatch_meta_table t
	on t.sql_instance = i.sql_instance
	and t.sqlwatch_database_id = i.sqlwatch_database_id
	and t.sqlwatch_table_id = i.sqlwatch_table_id

inner join dbo.sqlwatch_meta_database d
	on d.sql_instance = ius.sql_instance
	and d.sqlwatch_database_id = ius.sqlwatch_database_id;