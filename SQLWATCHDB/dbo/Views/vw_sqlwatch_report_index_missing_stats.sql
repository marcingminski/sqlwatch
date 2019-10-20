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
	  --,mdb.database_name
	  --,mdt.table_name
	  --,mdt.table_type
	  --,mdt.date_added
	  --,mdt.date_deleted
  FROM [dbo].[sqlwatch_logger_index_missing_stats] ims
	
	--inner join [dbo].[sqlwatch_meta_table] mdt
	--	on mdt.sql_instance = ims.sql_instance
	--	and mdt.sqlwatch_table_id = ims.sqlwatch_table_id
	--	and mdt.sqlwatch_database_id = ims.sqlwatch_database_id

	--inner join [dbo].[sqlwatch_meta_database] mdb
	--	on mdb.sql_instance = mdt.sql_instance
	--	and mdb.sqlwatch_database_id = mdt.sqlwatch_database_id
