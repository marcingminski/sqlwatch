CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_usage_stats_histogram] with schemabinding
as

SELECT d.[sqlwatch_database_id]
      ,d.[sqlwatch_table_id]
      ,d.[sqlwatch_index_id]
      ,d.[sqlwatch_stat_range_id]
      ,d.[RANGE_HI_KEY]
      ,d.[RANGE_ROWS]
      ,d.[EQ_ROWS]
      ,d.[DISTINCT_RANGE_ROWS]
      ,d.[AVG_RANGE_ROWS]
      ,report_time
      ,d.[collection_time]
      ,d.[sql_instance]
	  ,pbi_sqlwatch_index_id = d.sql_instance + '.DB.' + convert(varchar(10),d.sqlwatch_database_id) + '.TBL.' + convert(varchar(10),d.[sqlwatch_table_id]) +'.IDX.' + convert(varchar(10),d.sqlwatch_index_id)

  FROM [dbo].[sqlwatch_logger_index_usage_stats_histogram] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
