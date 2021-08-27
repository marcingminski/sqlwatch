CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_os_process_memory]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin
	
	set nocount on;

	insert into dbo.[sqlwatch_logger_dm_os_process_memory] (
		 
		 [physical_memory_in_use_kb] 
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
		
		,[snapshot_time] 
		,[snapshot_type_id] 
		,[sql_instance] 
	)
	select

		 [physical_memory_in_use_kb] 
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
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from openxml (@xdoc, '/CollectionSnapshot/dm_os_process_memory/row',1) 
	with (
		 physical_memory_in_use_kb bigint  
		,large_page_allocations_kb bigint  
		,locked_page_allocations_kb bigint 
		,total_virtual_address_space_kb bigint  
		,virtual_address_space_reserved_kb bigint  
		,virtual_address_space_committed_kb bigint 
		,virtual_address_space_available_kb bigint 
		,page_fault_count bigint  
		,memory_utilization_percentage int  
		,available_commit_limit_kb bigint  
		,process_physical_memory_low bit  
		,process_virtual_memory_low bit  
	)
	option (maxdop 1, keep plan);	
end;