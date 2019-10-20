CREATE VIEW [dbo].[vw_sqlwatch_report_perf_os_process_memory] with schemabinding
as
SELECT [report_time] = convert(smalldatetime,[snapshot_time])
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
      ,[sql_instance]
  FROM [dbo].[sqlwatch_logger_perf_os_process_memory]