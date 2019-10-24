CREATE TABLE [dbo].[sqlwatch_logger_perf_os_wait_stats]
(
	[wait_type_id] smallint not null,
	[waiting_tasks_count] bigint not null,
	[wait_time_ms] bigint not null,
	[max_wait_time_ms] bigint not null,
	[signal_wait_time_ms] bigint not null,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,

	[waiting_tasks_count_delta] real null,
	[wait_time_ms_delta] real null,
	[max_wait_time_ms_delta] real null,
	[signal_wait_time_ms_delta] real null,
	[delta_seconds] int null,
	constraint fk_sql_perf_mon_wait_stats_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	constraint [pk_sql_perf_mon_wait_stats] primary key (
		[snapshot_time] asc, [snapshot_type_id] asc, [sql_instance] asc, [wait_type_id] asc
		),
	constraint fk_sqlwatch_logger_perf_os_wait_stats_wait_type_id foreign key ([sql_instance], [wait_type_id]) 
		references [dbo].[sqlwatch_meta_wait_stats] ( [sql_instance], [wait_type_id] ) on delete cascade
) 

go

/* aid filtering by server in the central repository */
--CREATE NONCLUSTERED INDEX idx_sqlwatch_wait_stats_001
--ON [dbo].[sqlwatch_logger_perf_os_wait_stats] ([sql_instance])
--INCLUDE ([wait_type_id],[waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms],[snapshot_time],[snapshot_type_id])
--GO

CREATE NONCLUSTERED INDEX idx_sqlwatch_index_usage_stats_002
ON [dbo].[sqlwatch_logger_perf_os_wait_stats] ([wait_type_id],[sql_instance])
INCLUDE ([waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms])
