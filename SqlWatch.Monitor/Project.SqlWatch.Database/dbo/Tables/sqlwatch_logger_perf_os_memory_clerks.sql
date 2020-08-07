CREATE TABLE [dbo].[sqlwatch_logger_perf_os_memory_clerks]
(
	[snapshot_time] datetime2(0) not null,
	[total_kb] bigint,
	[allocated_kb] bigint,
	[sqlwatch_mem_clerk_id] smallint,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_perf_os_memory_clerks_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_perf_os_memory_clerks_sql_instance default (@@SERVERNAME),
	constraint fk_sql_perf_mon_os_memory_clerks_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	/* identifying relation */
	constraint [pk_sql_perf_mon_os_memory_clerks] primary key (
		[snapshot_time], [snapshot_type_id], [sql_instance], [sqlwatch_mem_clerk_id]
		),
	constraint fk_sqlwatch_logger_perf_os_memory_clerks_meta foreign key ([sql_instance], [sqlwatch_mem_clerk_id])
		references [dbo].[sqlwatch_meta_memory_clerk] ([sql_instance], [sqlwatch_mem_clerk_id]) on delete cascade
)
go
--CREATE NONCLUSTERED INDEX idx_sqlwatch_os_memory_clerks_001
--ON [dbo].[sqlwatch_logger_perf_os_memory_clerks] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])
