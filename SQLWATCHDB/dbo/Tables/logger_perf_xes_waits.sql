CREATE TABLE [dbo].[logger_perf_xes_waits]
(
	[event_time] datetime,
	[session_id] int,
	[wait_type] varchar(255),
	[duration] bigint,
	[signal_duration] bigint,
	[wait_resource] varchar(255),
	[query] varchar(max),
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 6 ,
	constraint fk_logger_xes_waits_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_logger_xes_waits] primary key (
		[snapshot_time] asc, [event_time], [wait_type] asc, [session_id]
		)
)
