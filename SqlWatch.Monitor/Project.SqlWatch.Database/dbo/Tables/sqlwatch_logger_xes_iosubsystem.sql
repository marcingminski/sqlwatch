CREATE TABLE [dbo].[sqlwatch_logger_xes_iosubsystem]
(
	[event_time] datetime,
	[io_latch_timeouts] bigint,
	[total_long_ios] bigint,
	[longest_pending_request_file] varchar(255),
	[longest_pending_request_duration] bigint,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_xes_iosubsystem_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_xes_iosubsystem_sql_instance default (@@SERVERNAME),
	constraint fk_logger_performance_xes_iosubsystem_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint [pk_logger_performance_xes_iosubsystem] primary key (
		[snapshot_time], [snapshot_type_id], [sql_instance], [event_time]
		),
	constraint fk_sqlwatch_logger_xes_iosubsystem_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go

--CREATE NONCLUSTERED INDEX idx_sqlwatch_xes_iosubsystem_001
--ON [dbo].[sqlwatch_logger_xes_iosubsystem] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])