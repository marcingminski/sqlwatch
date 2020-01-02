CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_histogram] with schemabinding
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
	  ,is_latest = case when d.snapshot_time = t.snapshot_time and d.sql_instance = t.sql_instance then 1 else 0 end
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_index_histogram] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	outer apply (
		select sql_instance 
			, snapshot_time=max(snapshot_time)
			, snapshot_type_id 
		from dbo.sqlwatch_logger_snapshot_header h
		where sql_instance = d.sql_instance
		and snapshot_type_id = d.snapshot_type_id
		group by sql_instance, snapshot_type_id
		) t
