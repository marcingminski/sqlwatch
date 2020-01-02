CREATE TABLE [dbo].[sqlwatch_logger_perf_os_wait_stats]
(
	[wait_type_id] smallint not null,
	[waiting_tasks_count] real not null,
	[wait_time_ms] real not null,
	[max_wait_time_ms] real not null,
	[signal_wait_time_ms] real not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_perf_os_wait_stats_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_perf_os_wait_stats_sql_instance default (@@SERVERNAME),

	[waiting_tasks_count_delta] real not null,
	[wait_time_ms_delta] real not null,
	[max_wait_time_ms_delta] real not null,
	[signal_wait_time_ms_delta] real not null,
	[delta_seconds] int not null,
	constraint fk_sql_perf_mon_wait_stats_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint [pk_sql_perf_mon_wait_stats] primary key (
		[snapshot_time] asc, [snapshot_type_id] asc, [sql_instance] asc, [wait_type_id] asc
		),
	constraint fk_sqlwatch_logger_perf_os_wait_stats_wait_type_id foreign key ([sql_instance], [wait_type_id]) 
		references [dbo].[sqlwatch_meta_wait_stats] ( [sql_instance], [wait_type_id] ) on delete cascade
) 

go

create nonclustered index idx_sqlwatch_logger_perf_os_wait_stats_waiting_count_delta 
	on [dbo].[sqlwatch_logger_perf_os_wait_stats] ([waiting_tasks_count_delta]) include ([wait_time_ms_delta])
go

create nonclustered index idx_sqlwatch_logger_perf_os_wait_stats_wait_type_id 
	on [dbo].[sqlwatch_logger_perf_os_wait_stats] ([sql_instance], [wait_type_id])
go

/* aid filtering by server in the central repository */
--CREATE NONCLUSTERED INDEX idx_sqlwatch_wait_stats_001
--ON [dbo].[sqlwatch_logger_perf_os_wait_stats] ([sql_instance])
--INCLUDE ([wait_type_id],[waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms],[snapshot_time],[snapshot_type_id])
--GO

--CREATE NONCLUSTERED INDEX idx_sqlwatch_index_usage_stats_002
--ON [dbo].[sqlwatch_logger_perf_os_wait_stats] ([wait_type_id],[sql_instance])
--INCLUDE ([waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms])
