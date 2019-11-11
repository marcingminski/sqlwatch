CREATE TABLE [dbo].[sqlwatch_logger_report_action]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null default 18,
	[report_id] smallint not null,
	[action_id] smallint not null,
	[action_type] varchar(50),
	[action_subject] nvarchar(max),
	[action_body] nvarchar(max),
	constraint pk_sqlwatch_logger_report_action_action primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id], [action_id]
	),
	constraint fk_sqlwatch_logger_report_action_action foreign key ([action_id])	
		references [dbo].[sqlwatch_config_action] ([action_id]) on delete cascade
)
