CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_database] with schemabinding
	AS 
SELECT d.[sqlwatch_database_id]
	  ,db.[database_name]
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

	  ,d.[unallocated_extent_page_count] 
	  ,d.[allocated_extent_page_count] 
	  ,d.[version_store_reserved_page_count] 
	  ,d.[user_object_reserved_page_count] 
	  ,d.[internal_object_reserved_page_count] 
	  ,d.[mixed_extent_page_count] 

 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_disk_utilisation_database] d

  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_database] db
	on db.sql_instance = d.sql_instance
	and db.sqlwatch_database_id = d.sqlwatch_database_id