CREATE TABLE [dbo].[sqlwatch_meta_alert_notify_queue]
(
	[sql_instance] varchar(32) not null,
	[notify_id] bigint identity(1,1) not null,
	[notify_timestamp] datetime2(7) default sysdatetime(),
	[check_id] smallint not null,
	[target_type] varchar(50) not null,
	[message_payload] varchar(max) not null,
	[send_status] tinyint default 0, --0 awaiting send, 1 = sending, 2 = failed to send
	[send_error_message] varchar(1024) null,
	constraint pk_sqlwatch_meta_alert_notify_queue primary key clustered (
		[sql_instance], [notify_id]
	),
	constraint fk_sqlwatch_meta_alert_notify_queue_check foreign key ([sql_instance], [check_id])
		references [dbo].[sqlwatch_config_alert_check] ([sql_instance], [check_id])
)
