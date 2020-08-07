CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_process_memory] with schemabinding
as
SELECT report_time
      ,[physical_memory_in_use_kb]
      ,[large_page_allocations_kb]
      ,[locked_page_allocations_kb]
      ,[total_virtual_address_space_kb]
      ,[virtual_address_space_reserved_kb]
      ,[virtual_address_space_committed_kb]
      ,[virtual_address_space_available_kb]
      ,[page_fault_count]
      ,[memory_utilization_percentage]
      ,[available_commit_limit_kb]
      ,[process_physical_memory_low]
      ,[process_virtual_memory_low]
      ,d.[sql_instance]
	  ,d.snapshot_type_id
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
  FROM [dbo].[sqlwatch_logger_perf_os_process_memory] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance