CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_database] with schemabinding
	AS 
SELECT d.[sqlwatch_database_id]
      ,d.[database_size_bytes]
      ,d.[unallocated_space_bytes]
      ,d.[reserved_bytes]
      ,d.[data_bytes]
      ,d.[index_size_bytes]
      ,d.[unused_bytes]
      ,d.[log_size_total_bytes]
      ,d.[log_size_used_bytes]
      ,h.report_time
      ,d.[sql_instance]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
  FROM [dbo].[sqlwatch_logger_disk_utilisation_database] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance