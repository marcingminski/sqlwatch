CREATE TABLE [dbo].[sql_perf_mon_os_memory_clerks]
(
	[snapshot_time] datetime not null,
	[total_kb] bigint,
	[allocated_kb] bigint,
	[total_kb_all_clerks] bigint,
	[clerk_name] varchar(255),
	[memory_available] int,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_sql_perf_mon_os_memory_clerks_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_sql_perf_mon_os_memory_clerks] primary key (
		[snapshot_time], [clerk_name]
		)
)
