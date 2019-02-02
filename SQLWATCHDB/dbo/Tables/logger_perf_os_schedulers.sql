CREATE TABLE [dbo].[logger_perf_os_schedulers](
	[snapshot_time] [datetime] NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL default 1,
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
	constraint fk_logger_perf_os_schedulers foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint pk_logger_perf_os_schedulers primary key clustered (
		[snapshot_time] ASC
	)
) ON [PRIMARY]
GO