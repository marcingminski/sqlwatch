CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_index_stats]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 select *, collection_sequence = ROW_NUMBER() over (partition by sql_instance, sqlwatch_database_id, sqlwatch_table_id, sqlwatch_index_id, partition_id order by snapshot_time)
into #sqlwatch_logger_index_usage_stats
from [dbo].[sqlwatch_logger_index_usage_stats]

CREATE NONCLUSTERED INDEX idx_tmp_sqlwatch_logger_index_usage_stats
ON #sqlwatch_logger_index_usage_stats ([sqlwatch_database_id],[sqlwatch_index_id],[sql_instance],[sqlwatch_table_id])
INCLUDE ([used_pages_count],[user_seeks],[user_scans],[user_lookups],[user_updates],[partition_id],[collection_sequence])

 select 
       us2.sqlwatch_database_id
	   ,us2.sqlwatch_table_id
	   ,us2.sqlwatch_index_id
      ,us2.[used_pages_count]
      ,[user_seeks] = us2.[user_seeks] - us1.[user_seeks]
      ,[user_scans] = us2.[user_scans] - us1.[user_scans]
      ,[user_lookups] = us2.[user_lookups] - us1.[user_lookups]
      ,[user_updates] = us2.[user_updates] - us1.[user_updates]
      ,us2.[last_user_seek] 
      ,us2.[last_user_scan]
      ,us2.[last_user_lookup]
      ,us2.[last_user_update]
      ,us2.[stats_date]
      ,[index_status] = case when us2.[index_disabled] = 1 then 'DISABLED' else 'ENABLED' end
      ,us2.sql_instance
      ,	[report_time] = us2.[snapshot_time]
	  , us2.partition_id
from #sqlwatch_logger_index_usage_stats us1

	inner join #sqlwatch_logger_index_usage_stats us2
		on us2.sql_instance = us1.sql_instance
		and us2.sqlwatch_index_id = us1.sqlwatch_index_id
		and us2.sqlwatch_database_id = us1.sqlwatch_database_id
		and us2.sqlwatch_table_id = us1.sqlwatch_table_id
		and us2.[partition_id] = us1.[partition_id]
		and us2.collection_sequence = us1.collection_sequence + 1

	--inner join [dbo].[sqlwatch_meta_index] mi
	--	on mi.sql_instance = us2.sql_instance
	--	and mi.sqlwatch_database_id = us2.sqlwatch_database_id
	--	and mi.sqlwatch_table_id = us2.sqlwatch_table_id
	--	and mi.sqlwatch_index_id = us2.sqlwatch_index_id

	--inner join [dbo].[sqlwatch_meta_table] mtb
	--	on mtb.sql_instance = mi.sql_instance
	--	and mtb.sqlwatch_database_id = mi.sqlwatch_database_id
	--	and mtb.sqlwatch_table_id = mi.sqlwatch_table_id

	--inner join [dbo].[sqlwatch_meta_database] mdb
	--	on mdb.sql_instance = mtb.sql_instance
	--	and mdb.sqlwatch_database_id = mtb.sqlwatch_database_id

where	
		us2.[snapshot_time] >= DATEADD(DAY, -@report_window, @report_end_time)
	and us2.[snapshot_time] <= @report_end_time
	and us2.sql_instance = isnull(@sql_instance,us2.sql_instance)