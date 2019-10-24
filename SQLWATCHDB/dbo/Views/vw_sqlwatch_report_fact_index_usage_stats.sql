CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats] with schemabinding
as
select [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [used_pages_count], [user_seeks], [user_scans], [user_lookups], [user_updates], [last_user_seek]
, [last_user_scan], [last_user_lookup], [last_user_update], [stats_date], report_time, [index_disabled], d.[sql_instance]
, [partition_id], [used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds_delta] 
, pbi_sqlwatch_index_id = d.sql_instance + '.DB.' + convert(varchar(10),d.sqlwatch_database_id) + '.TBL.' + convert(varchar(10),d.[sqlwatch_table_id]) +'.IDX.' + convert(varchar(10),d.sqlwatch_index_id)
from [dbo].[sqlwatch_logger_index_usage_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

