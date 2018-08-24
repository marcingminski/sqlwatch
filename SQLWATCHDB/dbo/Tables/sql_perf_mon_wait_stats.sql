CREATE TABLE [dbo].[sql_perf_mon_wait_stats]
(
	[wait_type] nvarchar(60) not null,
	[waiting_tasks_count] bigint not null,
	[wait_time_ms] bigint not null,
	[max_wait_time_ms] bigint not null,
	[signal_wait_time_ms] bigint not null,
	[snapshot_time] datetime foreign key references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time]) on delete cascade not null,
	constraint [pk_sql_perf_mon_wait_stats] primary key (
		[snapshot_time] asc, [wait_type] asc
		)
) 
