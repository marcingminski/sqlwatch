CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats] with schemabinding
as
with cte_index_sequence as (
	select [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [used_pages_count], [user_seeks], [user_scans], [user_lookups], [user_updates]
		 , [last_user_seek], [last_user_scan], [last_user_lookup], [last_user_update], [stats_date], [snapshot_time], [snapshot_type_id], [index_disabled], [sql_instance], [partition_id]

		 , [user_seeks_prev] = lag([user_seeks]) over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
		 , [user_scans_prev] = lag([user_scans]) over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
		 , [user_lookups_prev] = lag([user_lookups]) over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
		 , [user_updates_prev] = lag([user_updates]) over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
		, [snapshot_time_prev] = lag([snapshot_time]) over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
	from [dbo].[sqlwatch_logger_index_usage_stats]
	)
SELECT [sqlwatch_database_id]
      ,[sqlwatch_table_id]
      ,[sqlwatch_index_id]
      ,[used_pages_count]
      ,[user_seeks] = case when [user_seeks] > [user_seeks_prev] then [user_seeks] - [user_seeks_prev] else 0 end
      ,[user_scans] = case when [user_scans] > [user_scans_prev] then [user_scans] - [user_scans_prev] else 0 end
      ,[user_lookups] = case when [user_lookups] > [user_lookups_prev] then [user_lookups] - [user_lookups_prev] else 0 end
      ,[user_updates] = case when [user_updates_prev] > [user_updates_prev] then [user_updates] - [user_updates_prev] else 0 end
      ,[last_user_seek]
      ,[last_user_scan]
      ,[last_user_lookup]
      ,[last_user_update]
      ,[stats_date]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,[index_disabled]
      ,[sql_instance]
      ,[partition_id]
  FROM cte_index_sequence
