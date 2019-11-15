CREATE TABLE [dbo].[sqlwatch_meta_action_queue]
(
	[sql_instance] varchar(32) not null,
	[queue_item_id] bigint identity(1,1) not null,
	[action_exec_type] varchar(50) not null,
	[time_queued] datetime2(7) default sysdatetime(),
	[action_exec] varchar(max) not null,
	[exec_status] varchar(50) null, --null awaiting send, -1 = processing, othewrise error_code, 
	[exec_error_message] varchar(1024) null,
	constraint pk_sqlwatch_meta_delivery_queue primary key clustered (
		[sql_instance], [queue_item_id]
	),
	constraint chk_sqlwatch_meta_action_queue_status check ([exec_status] is NULL or [exec_status] in ('OK','PROCESSING','FAILED'))
)
