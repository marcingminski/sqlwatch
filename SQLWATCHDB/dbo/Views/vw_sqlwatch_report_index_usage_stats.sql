CREATE VIEW [dbo].[vw_sqlwatch_report_index_usage_stats] with schemabinding
as
with cte_index_sequence as (
	select [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [used_pages_count], [user_seeks], [user_scans], [user_lookups], [user_updates]
		 , [last_user_seek], [last_user_scan], [last_user_lookup], [last_user_update], [stats_date], [snapshot_time], [snapshot_type_id], [index_disabled], [sql_instance], [partition_id]
		, [sequence] = DENSE_RANK() over (partition by [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id] order by [snapshot_time] desc)	
	from [dbo].[sqlwatch_logger_index_usage_stats]
	)
SELECT is2.[sqlwatch_database_id]
      ,is2.[sqlwatch_table_id]
      ,is2.[sqlwatch_index_id]
      ,is2.[used_pages_count]
      ,[user_seeks] = case when is2.[user_seeks] > is1.[user_seeks] then is2.[user_seeks] - is1.[user_seeks] else 0 end
      ,[user_scans] = case when is2.[user_scans] > is1.[user_scans] then is2.[user_scans] - is1.[user_scans] else 0 end
      ,[user_lookups] = case when is2.[user_lookups] > is1.[user_lookups] then is2.[user_lookups] - is1.[user_lookups] else 0 end
      ,[user_updates] = case when is2.[user_updates] > is1.[user_updates] then is2.[user_updates] - is1.[user_updates] else 0 end
      ,is2.[last_user_seek]
      ,is2.[last_user_scan]
      ,is2.[last_user_lookup]
      ,is2.[last_user_update]
      ,is2.[stats_date]
      ,[report_time] = convert(smalldatetime,is1.[snapshot_time])
      ,is2.[index_disabled]
      ,is2.[sql_instance]
      ,is2.[partition_id]

	  --,mi.index_type_desc
	  --,mi.index_name
	  --,mi.date_added
	  --,mi.date_deleted
	  --,mdt.table_name
	  --,mdt.table_type
	  --,mdb.database_name
	  ,is_latest = case when is2.[sequence] = 1 then 1 else 0 end
  FROM cte_index_sequence is1

	inner join cte_index_sequence is2
		on is1.sql_instance = is1.sql_instance
		and is1.sqlwatch_database_id = is2.sqlwatch_database_id
		and is1.sqlwatch_table_id = is2.sqlwatch_table_id
		and is1.sqlwatch_index_id = is2.sqlwatch_index_id
		and is1.sequence = is2.sequence + 1

	--inner join [dbo].[sqlwatch_meta_index] mi
	--	on mi.sql_instance = is2.sql_instance
	--	and mi.sqlwatch_table_id = is2.sqlwatch_table_id
	--	and mi.sqlwatch_database_id = is2.sqlwatch_database_id

	--inner join [dbo].[sqlwatch_meta_table] mdt
	--	on mdt.sql_instance = mi.sql_instance
	--	and mdt.sqlwatch_table_id = mi.sqlwatch_table_id
	--	and mdt.sqlwatch_database_id = mi.sqlwatch_database_id

	--inner join [dbo].[sqlwatch_meta_database] mdb
	--	on mdb.sql_instance = mdt.sql_instance
	--	and mdb.sqlwatch_database_id = mdt.sqlwatch_database_id
