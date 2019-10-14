CREATE TABLE [dbo].[sqlwatch_logger_perf_os_memory_clerks]
(
	[snapshot_time] datetime not null,
	[total_kb] bigint,
	[allocated_kb] bigint,
	[total_kb_all_clerks] bigint,
	[sqlwatch_mem_clerk_id] smallint,
	[memory_available] int,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_os_memory_clerks_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	/* identifying relation */
	constraint [pk_sql_perf_mon_os_memory_clerks] primary key (
		[snapshot_time], [snapshot_type_id], [sql_instance], [sqlwatch_mem_clerk_id]
		)
)
go
CREATE NONCLUSTERED INDEX idx_sqlwatch_os_memory_clerks_001
ON [dbo].[sqlwatch_logger_perf_os_memory_clerks] ([sql_instance])
INCLUDE ([snapshot_time],[snapshot_type_id])
