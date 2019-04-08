CREATE TABLE [dbo].[sqlwatch_logger_xes_iosubsystem]
(
	[event_time] datetime,
	[io_latch_timeouts] bigint,
	[total_long_ios] bigint,
	[longest_pending_request_file] varchar(255),
	[longest_pending_request_duration] bigint,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_logger_performance_xes_iosubsystem_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	constraint [pk_logger_performance_xes_iosubsystem] primary key (
		[snapshot_time] asc, [event_time]
		)
)
