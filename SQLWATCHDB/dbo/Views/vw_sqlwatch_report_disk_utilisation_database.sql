CREATE VIEW [dbo].[vw_sqlwatch_report_disk_utilisation_database] with schemabinding
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
	  --,mdb.database_name
  FROM [dbo].[sqlwatch_logger_disk_utilisation_database] udb

	--inner join [dbo].[sqlwatch_meta_database] mdb
	--	on mdb.sql_instance = udb.sql_instance
	--	and mdb.sqlwatch_database_id = udb.sqlwatch_database_id
