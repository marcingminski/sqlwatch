CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats_histogram] with schemabinding
as

SELECT ih.[sqlwatch_database_id]
      ,ih.[sqlwatch_table_id]
      ,ih.[sqlwatch_index_id]
      ,ih.[sqlwatch_stat_range_id]
      ,ih.[RANGE_HI_KEY]
      ,ih.[RANGE_ROWS]
      ,ih.[EQ_ROWS]
      ,ih.[DISTINCT_RANGE_ROWS]
      ,ih.[AVG_RANGE_ROWS]
      ,report_time
      ,ih.[collection_time]
      ,ih.[sql_instance]
  FROM [dbo].[sqlwatch_logger_index_usage_stats_histogram] ih
    inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = ih.sql_instance
		and sh.snapshot_time = ih.[snapshot_time]
		and sh.snapshot_type_id = ih.snapshot_type_id
