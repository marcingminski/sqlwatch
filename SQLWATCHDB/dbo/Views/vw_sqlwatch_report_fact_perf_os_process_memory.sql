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
      ,pm.[sql_instance]
  FROM [dbo].[sqlwatch_logger_perf_os_process_memory] pm
      inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = pm.sql_instance
		and sh.snapshot_time = pm.[snapshot_time]
		and sh.snapshot_type_id = pm.snapshot_type_id