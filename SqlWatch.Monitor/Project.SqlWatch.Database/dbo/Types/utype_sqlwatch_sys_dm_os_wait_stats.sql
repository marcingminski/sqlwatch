CREATE TYPE [dbo].[utype_sqlwatch_sys_dm_os_wait_stats] AS TABLE
(
	[wait_type] nvarchar(60),
	[waiting_tasks_count] bigint,
	[wait_time_ms] bigint,
	[max_wait_time_ms] bigint,
	[signal_wait_time_ms] bigint,
	snapshot_time datetime2(0),
	snapshot_type_id tinyint,
	sql_instance varchar(32)
);