CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_missing_stats] with schemabinding
as
SELECT d.[sqlwatch_database_id]
      ,d.[sqlwatch_table_id]
      ,d.[sqlwatch_missing_index_id]
      ,d.[sqlwatch_missing_index_stats_id]
      ,report_time
      ,[last_user_seek]
      ,[unique_compiles]
      ,[user_seeks]
      ,[user_scans]
      ,[avg_total_user_cost]
      ,[avg_user_impact]
      ,d.[sql_instance]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_index_missing_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

