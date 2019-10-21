CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_database] with schemabinding
	AS 
SELECT udb.[sqlwatch_database_id]
      ,[database_size_bytes]
      ,[unallocated_space_bytes]
      ,[reserved_bytes]
      ,[data_bytes]
      ,[index_size_bytes]
      ,[unused_bytes]
      ,[log_size_total_bytes]
      ,[log_size_used_bytes]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,udb.[sql_instance]
  FROM [dbo].[sqlwatch_logger_disk_utilisation_database] udb