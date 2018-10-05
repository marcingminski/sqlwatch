CREATE TABLE [dbo].[logger_perf_xes_query_processing]
(
	[event_time] datetime,
	[max_workers] bigint,
	[workers_created] bigint,
	[idle_workers] bigint,
	[pending_tasks] bigint,
	[unresolvable_deadlocks] int,
	[deadlocked_scheduler] int,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_logger_xe_query_processing_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_logger_xe_query_processing] primary key (
		[snapshot_time] asc, [event_time]
		)
)
