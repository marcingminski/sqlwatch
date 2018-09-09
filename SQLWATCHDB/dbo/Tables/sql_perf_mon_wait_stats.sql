CREATE TABLE [dbo].[sql_perf_mon_wait_stats]
(
	[wait_type] nvarchar(60) not null,
	[waiting_tasks_count] bigint not null,
	[wait_time_ms] bigint not null,
	[max_wait_time_ms] bigint not null,
	[signal_wait_time_ms] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_sql_perf_mon_wait_stats_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_sql_perf_mon_wait_stats] primary key (
		[snapshot_time] asc, [wait_type] asc
		)
) 
