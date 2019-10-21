CREATE VIEW [dbo].[vw_sqlwatch_report_index_missing_stats] with schemabinding
as
SELECT ims.[sqlwatch_database_id]
      ,ims.[sqlwatch_table_id]
      ,ims.[sqlwatch_missing_index_detail_id]
      ,ims.[sqlwatch_missing_index_stats_id]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,[last_user_seek]
      ,[unique_compiles]
      ,[user_seeks]
      ,[user_scans]
      ,[avg_total_user_cost]
      ,[avg_user_impact]
      ,ims.[sql_instance]
  FROM [dbo].[sqlwatch_logger_index_missing_stats] ims

