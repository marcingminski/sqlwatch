CREATE TABLE [dbo].[sqlwatch_logger_perf_os_process_memory]
(
	[snapshot_time] datetime2(0) NOT NULL,
	[physical_memory_in_use_kb] [bigint] NOT NULL,
	[large_page_allocations_kb] [bigint] NOT NULL,
	[locked_page_allocations_kb] [bigint] NOT NULL,
	[total_virtual_address_space_kb] [bigint] NOT NULL,
	[virtual_address_space_reserved_kb] [bigint] NOT NULL,
	[virtual_address_space_committed_kb] [bigint] NOT NULL,
	[virtual_address_space_available_kb] [bigint] NOT NULL,
	[page_fault_count] [bigint] NOT NULL,
	[memory_utilization_percentage] [int] NOT NULL,
	[available_commit_limit_kb] [bigint] NOT NULL,
	[process_physical_memory_low] [bit] NOT NULL,
	[process_virtual_memory_low] [bit] NOT NULL,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_perf_os_process_memory_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_perf_os_process_memory_sql_instance default (@@SERVERNAME),
	constraint fk_sql_perf_mon_os_process_memory_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint pk_sql_perf_mon_os_process_memory primary key clustered (
		[snapshot_time], [snapshot_type_id], [sql_instance]
	),
	constraint fk_sqlwatch_logger_perf_os_process_memory_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
) 
GO

--CREATE NONCLUSTERED INDEX idx_sqlwatch_os_process_memory_001
--ON [dbo].[sqlwatch_logger_perf_os_process_memory] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])
