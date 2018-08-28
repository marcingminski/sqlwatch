CREATE TABLE [dbo].[sql_perf_mon_os_memory_clerks]
(
	[snapshot_time] datetime foreign key references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time]) on delete cascade not null,
	[total_kb] bigint,
	[allocated_kb] bigint,
	[total_kb_all_clerks] bigint,
	[clerk_name] varchar(255),
	[memory_available] int,
	constraint [pk_sql_perf_mon_os_memory_clerks] primary key (
		[snapshot_time], [clerk_name]
		)
)
