CREATE TABLE [dbo].[sqlwatch_stage_perf_os_wait_stats]
(
	[wait_type] [nvarchar](60) NOT NULL,
	[waiting_tasks_count] [bigint] NOT NULL,
	[wait_time_ms] [bigint] NOT NULL,
	[max_wait_time_ms] [bigint] NOT NULL,
	[signal_wait_time_ms] [bigint] NOT NULL,
	snapshot_time datetime2(0),
	constraint pk_sqlwatch_stage_perf_os_wait_stats primary key clustered (
		snapshot_time, wait_type
		)
)