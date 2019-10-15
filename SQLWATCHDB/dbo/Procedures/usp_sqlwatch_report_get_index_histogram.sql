CREATE PROCEDURE [dbo].[usp_sqlwatch_report_get_index_histogram]
(
	@interval_minutes smallint = null,
	@report_window int = null,
	@report_end_time datetime = null,
	@sql_instance nvarchar(25) = null
	)
as
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	set @report_end_time = isnull(@report_end_time,getutcdate())

	/* due to the potential size of the histogram table, we are only going to grab the most recent histogram for the report_end_time
	   to see previous histograms, adjust report_end_time accordingly */
    select 
	  -- [database_name] = mdb.[database_name]
	  --,[table_name] = mtb.table_name
	  sh.sqlwatch_database_id
	  ,sh.sqlwatch_table_id
	  ,sh.sqlwatch_index_id
      ,sh.[RANGE_HI_KEY]
      ,sh.[RANGE_ROWS]
      ,sh.[EQ_ROWS]
      ,sh.[DISTINCT_RANGE_ROWS]
      ,sh.[AVG_RANGE_ROWS]
      ,sh.[sql_instance]
      ,[report_time] = sh.collection_time
from [dbo].[sqlwatch_logger_index_usage_stats_histogram] sh

	--get most recent histogram per table only:
	inner join (
		select last_collection_time = max(collection_time),
			sqlwatch_database_id, sqlwatch_table_id, sqlwatch_index_id, sql_instance
		from [dbo].[sqlwatch_logger_index_usage_stats_histogram]
		where collection_time <= @report_end_time
		group by sqlwatch_database_id, sqlwatch_table_id, sqlwatch_index_id, sql_instance
	) r
	on r.sql_instance = sh.sql_instance
	and r.sqlwatch_database_id = sh.sqlwatch_database_id
	and r.sqlwatch_table_id = sh.sqlwatch_table_id
	and r.sqlwatch_index_id = sh.sqlwatch_index_id
	and r.last_collection_time = sh.collection_time


where		sh.[snapshot_time] >= DATEADD(DAY, -@report_window, @report_end_time)
		and sh.[snapshot_time] <= @report_end_time
		and sh.sql_instance = isnull(@sql_instance,sh.sql_instance)