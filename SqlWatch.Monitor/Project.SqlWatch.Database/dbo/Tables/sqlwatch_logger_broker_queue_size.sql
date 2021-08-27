CREATE TABLE [dbo].[sqlwatch_logger_broker_queue_size]
(
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint,
	[sql_instance] varchar(32),
	[queue_name]  nvarchar(128),
	[message_count] int,

	constraint pk_sqlwatch_logger_broker_queue_size
		primary key clustered (snapshot_time, snapshot_type_id, sql_instance, [queue_name]),

	constraint fk_sqlwatch_logger_broker_queue_size_header
		foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [sql_instance], [snapshot_type_id])
		on delete cascade
)
