CREATE VIEW [dbo].[vw_sqlwatch_report_fact_index_missing_stats] with schemabinding
as
SELECT ims.[sqlwatch_database_id]
      ,ims.[sqlwatch_table_id]
      ,ims.[sqlwatch_missing_index_id]
      ,ims.[sqlwatch_missing_index_stats_id]
      ,report_time
      ,[last_user_seek]
      ,[unique_compiles]
      ,[user_seeks]
      ,[user_scans]
      ,[avg_total_user_cost]
      ,[avg_user_impact]
      ,ims.[sql_instance]
	  ,pbi_sqlwatch_missing_index_id = ims.sql_instance + '.DB.' + convert(varchar(10),ims.sqlwatch_database_id) + '.TBL.' + convert(varchar(10),ims.[sqlwatch_table_id]) +'.MIDX.' + convert(varchar(10),ims.sqlwatch_missing_index_id)

  FROM [dbo].[sqlwatch_logger_index_missing_stats] ims
    	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = ims.sql_instance
		and sh.snapshot_time = ims.[snapshot_time]
		and sh.snapshot_type_id = ims.snapshot_type_id

