CREATE TABLE [dbo].[sqlwatch_logger_action]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null default 19,
	[action_id] smallint not null,
	[action_status] bit not null,
	[action_error] nvarchar(max) null,
	constraint pk_sqlwatch_logger_action primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id]
	),
	constraint fk_sqlwatch_logger_action_header foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade,
	constraint fk_sqlwatch_logger_action_action foreign key ([action_id])
		references [dbo].[sqlwatch_config_action] ([action_id]) on delete cascade
)
