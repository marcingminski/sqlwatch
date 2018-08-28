CREATE VIEW [dbo].[vw_sql_perf_mon_rep_mem_proc] AS
	select
		 [report_name] = 'process memory'
		,[report_time] = s.[snapshot_interval_end] 
		,[Physical memory in use (MB)]=avg([physical_memory_in_use_kb]/1024)
		,[Locked page allocations (MB)]=avg([locked_page_allocations_kb]/1024)
		,[Page faults]=avg([page_fault_count])
		,[Memory utilisation %]=avg([memory_utilization_percentage])
		,s.[report_time_interval_minutes]
	from [dbo].[sql_perf_mon_os_process_memory]  pm
	inner join [dbo].[vw_sql_perf_mon_time_intervals] s
		on pm.snapshot_time >= s.first_snapshot_time
		and pm.snapshot_time <= s.last_snapshot_time
	group by s.[snapshot_interval_end],s.[report_time_interval_minutes]
