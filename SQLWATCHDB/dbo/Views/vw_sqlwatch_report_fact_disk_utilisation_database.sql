CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_database] with schemabinding
	AS 
SELECT udb.[sqlwatch_database_id]
      ,udb.[database_size_bytes]
      ,udb.[unallocated_space_bytes]
      ,udb.[reserved_bytes]
      ,udb.[data_bytes]
      ,udb.[index_size_bytes]
      ,udb.[unused_bytes]
      ,udb.[log_size_total_bytes]
      ,udb.[log_size_used_bytes]
      ,sh.report_time
      ,udb.[sql_instance]
	  ,pbi_sqlwatch_database_id = udb.sql_instance + '.DB.' + convert(varchar(10),udb.sqlwatch_database_id)
  FROM [dbo].[sqlwatch_logger_disk_utilisation_database] udb
	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = udb.sql_instance
		and sh.snapshot_time = udb.[snapshot_time]
		and sh.snapshot_type_id = udb.snapshot_type_id