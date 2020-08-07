CREATE TABLE [dbo].[sqlwatch_logger_perf_os_schedulers](
	[snapshot_time] datetime2(0) NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL constraint df_sqlwatch_logger_perf_os_schedulers_type default (1),
	[scheduler_count] [smallint] null,
	[idle_scheduler_count] smallint null,
	[current_tasks_count] int NULL,
	[runnable_tasks_count] int NULL,
	[preemptive_switches_count] [bigint] NULL,
	[context_switches_count] [bigint] NULL,
	[idle_switches_count] [bigint] NULL,
	[current_workers_count] int NULL,
	[active_workers_count] int NULL,
	[work_queue_count] int NULL,
	[pending_disk_io_count] int NULL,
	[load_factor] int NULL,
	[yield_count] [bigint] NULL,
	[failed_to_create_worker] int NULL,
	[total_cpu_usage_ms] [bigint] NULL,
	[total_scheduler_delay_ms] [bigint] NULL,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_perf_os_schedulers_sql_instance default (@@SERVERNAME),
	constraint fk_logger_perf_os_schedulers foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint pk_logger_perf_os_schedulers primary key clustered (
		[snapshot_time] ASC, [snapshot_type_id],  [sql_instance]
	),
	constraint fk_sqlwatch_logger_perf_os_schedulers_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
) 
GO

--CREATE NONCLUSTERED INDEX idx_sqlwatch_os_schedulers_001
--ON [dbo].[sqlwatch_logger_perf_os_schedulers] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])	