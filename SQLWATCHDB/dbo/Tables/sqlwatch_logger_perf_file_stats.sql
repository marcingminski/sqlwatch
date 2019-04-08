CREATE TABLE [dbo].[sqlwatch_logger_perf_file_stats]
(
	[database_name] nvarchar(128) not null,
	[logical_file_name] sysname not null,
	[type_desc] nvarchar(60) not null,
	[logical_disk] varchar(255) not null,
	[num_of_reads] bigint not null,
	[num_of_bytes_read] bigint not null,
	[io_stall_read_ms] bigint not null,
	[num_of_writes] bigint not null,
	[num_of_bytes_written] bigint not null,
	[io_stall_write_ms] bigint not null,
	[size_on_disk_bytes] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_file_stats_snapshot_header foreign key ([snapshot_time],[snapshot_type_id], [sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id], [sql_instance]) on delete cascade ,
	constraint pk_sql_perf_mon_file_stats primary key clustered (
		[snapshot_time], [database_name], [logical_file_name], [type_desc], [sql_instance]
	)
)
