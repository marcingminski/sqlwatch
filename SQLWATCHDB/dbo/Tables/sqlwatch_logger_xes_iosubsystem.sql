CREATE TABLE [dbo].[sqlwatch_logger_xes_iosubsystem]
(
	[event_time] datetime,
	[io_latch_timeouts] bigint,
	[total_long_ios] bigint,
	[longest_pending_request_file] varchar(255),
	[longest_pending_request_duration] bigint,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_logger_performance_xes_iosubsystem_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	constraint [pk_logger_performance_xes_iosubsystem] primary key (
		[snapshot_time] asc, [event_time],[sql_instance]
		)
)
