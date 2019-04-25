CREATE TABLE [dbo].[sqlwatch_logger_perf_os_memory_clerks]
(
	[snapshot_time] datetime not null,
	[total_kb] bigint,
	[allocated_kb] bigint,
	[total_kb_all_clerks] bigint,
	[clerk_name] varchar(255),
	[memory_available] int,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_os_memory_clerks_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	constraint [pk_sql_perf_mon_os_memory_clerks] primary key (
		[snapshot_time], [clerk_name]
		)
)
