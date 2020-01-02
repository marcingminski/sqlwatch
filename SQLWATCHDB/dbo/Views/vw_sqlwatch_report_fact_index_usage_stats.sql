CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats] with schemabinding
as
select [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [used_pages_count], [user_seeks], [user_scans], [user_lookups], [user_updates], [last_user_seek]
, [last_user_scan], [last_user_lookup], [last_user_update], [stats_date], report_time, [index_disabled], d.[sql_instance]
, [partition_id], [used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds]
, [user_lookups_delta]

, [update_ratio] = case when isnull([user_seeks]+[user_lookups]+[user_scans]+[user_updates],0) > 0 
	then [user_updates]/([user_seeks]+[user_lookups]+[user_scans]+[user_updates]) else 0 end 

, [scan_to_seek_ratio_delta] = case when isnull([user_seeks]+[user_scans]+[user_lookups],0) > 0 
	then [user_scans]/([user_seeks]+[user_scans]+[user_lookups]) else 0 end

, [update_ratio_delta] = case when isnull([user_seeks_delta]+[user_lookups_delta]+[user_scans_delta]+[user_updates_delta],0) > 0 
	then [user_updates_delta]/([user_seeks_delta]+[user_lookups_delta]+[user_scans_delta]+[user_updates_delta]) else 0 end 

, [scan_to_seek_ratio] = case when isnull([user_seeks_delta]+[user_scans_delta]+[user_lookups_delta],0) > 0 
	then [user_scans_delta]/([user_seeks_delta]+[user_scans_delta]+[user_lookups_delta]) else 0 end 

, [index_status] = case when [index_disabled] = 1 then 'DISABLED' else 'Enabled' end
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, show_usage_stats = convert(bit,1)
, d.snapshot_type_id
from [dbo].[sqlwatch_logger_index_usage_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

