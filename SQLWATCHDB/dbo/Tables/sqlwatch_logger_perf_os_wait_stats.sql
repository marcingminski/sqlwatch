CREATE TABLE [dbo].[sqlwatch_logger_perf_os_wait_stats]
(
	[wait_type] nvarchar(60) not null,
	[waiting_tasks_count] bigint not null,
	[wait_time_ms] bigint not null,
	[max_wait_time_ms] bigint not null,
	[signal_wait_time_ms] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_sql_perf_mon_wait_stats_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	constraint [pk_sql_perf_mon_wait_stats] primary key (
		[snapshot_time] asc, [snapshot_type_id] asc, [sql_instance] asc, [wait_type] asc
		)
) 
