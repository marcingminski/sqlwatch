CREATE TABLE [dbo].[sqlwatch_logger_check_action]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null default 18,
	[check_id] smallint not null,
	[action_id] smallint not null,
	[action_type] varchar(50),
	[action_attributes] nvarchar(max),
	constraint pk_sqlwatch_logger_check_action primary key clustered (
		[snapshot_time], [sql_instance], [check_id], [snapshot_type_id], [action_id]
	),
	constraint fk_sqlwatch_logger_check_action_logger_check foreign key (
		snapshot_time, sql_instance, check_id, snapshot_type_id
		) references [dbo].[sqlwatch_logger_check] (snapshot_time, sql_instance, check_id, snapshot_type_id) on delete cascade,
	constraint fk_sqlwatch_logger_check_action_action foreign key ([action_id])	
		references [dbo].[sqlwatch_config_action] ([action_id]) on delete cascade
)
go

create nonclustered index idx_sqlwatch_logger_check_action_type on [dbo].[sqlwatch_logger_check_action] ([action_type])
	include (sql_instance, check_id)