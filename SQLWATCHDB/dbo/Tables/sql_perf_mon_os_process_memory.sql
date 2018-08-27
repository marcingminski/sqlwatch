CREATE TABLE [dbo].[sql_perf_mon_os_process_memory]
(
	[snapshot_time] [datetime] NOT NULL,
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
PRIMARY KEY CLUSTERED 
(
	[snapshot_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[sql_perf_mon_os_process_memory]  WITH CHECK ADD  CONSTRAINT [fk_sql_perf_mon_os_process_memory] FOREIGN KEY([snapshot_time])
REFERENCES [dbo].[sql_perf_mon_snapshot_header] ([snapshot_time])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[sql_perf_mon_os_process_memory] CHECK CONSTRAINT [fk_sql_perf_mon_os_process_memory]
GO
