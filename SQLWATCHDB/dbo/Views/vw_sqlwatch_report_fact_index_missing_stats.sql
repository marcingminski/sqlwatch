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
	  ,pbi_sqlwatch_missing_index_id = d.sql_instance + '.DB.' + convert(varchar(10),d.sqlwatch_database_id) + '.TBL.' + convert(varchar(10),d.[sqlwatch_table_id]) +'.MIDX.' + convert(varchar(10),d.sqlwatch_missing_index_id)

  FROM [dbo].[sqlwatch_logger_index_missing_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

