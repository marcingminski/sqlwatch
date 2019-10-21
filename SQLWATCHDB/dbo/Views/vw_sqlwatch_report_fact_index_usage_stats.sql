CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats] with schemabinding
as
select [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [used_pages_count], [user_seeks], [user_scans], [user_lookups], [user_updates], [last_user_seek]
, [last_user_scan], [last_user_lookup], [last_user_update], [stats_date], report_time, [index_disabled], us.[sql_instance]
, [partition_id], [used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds_delta] 

from [dbo].[sqlwatch_logger_index_usage_stats] us
    	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = us.sql_instance
		and sh.snapshot_time = us.[snapshot_time]
		and sh.snapshot_type_id = us.snapshot_type_id

