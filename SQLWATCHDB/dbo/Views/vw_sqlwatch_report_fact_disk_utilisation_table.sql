CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_table] with schemabinding
as

select mdb.[database_name]
	  ,mdb.database_create_date
	  ,mt.table_name
      ,[row_count]
      ,[total_pages]
      ,[used_pages]
      ,[data_compression]
      ,h.[snapshot_type_id]
      ,h.[snapshot_time]
	  ,h.report_time
      ,ut.[sql_instance]
	  ,[row_count_delta]
	  ,[total_pages_delta]
	  ,[used_pages_delta]
	  ,ut.sqlwatch_database_id
	  ,ut.sqlwatch_table_id
  from [dbo].[sqlwatch_logger_disk_utilisation_table] ut
  
  inner join [dbo].[sqlwatch_meta_table] mt
	on mt.[sqlwatch_table_id] = ut.[sqlwatch_table_id]
	and mt.[sqlwatch_database_id] = ut.[sqlwatch_database_id]
	and mt.sql_instance = ut.sql_instance

  inner join [dbo].[sqlwatch_meta_database] mdb
	on mdb.sqlwatch_database_id = mt.sqlwatch_database_id
	and mdb.sql_instance = mt.sql_instance

  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = ut.[snapshot_time]
		and h.snapshot_type_id = ut.snapshot_type_id
		and h.sql_instance = ut.sql_instance