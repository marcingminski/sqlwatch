CREATE TABLE [dbo].[sqlwatch_logger_check_action]
(
	/* history of executed actions and attributes, i.e. a message log for actions */
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_check_action_type default (18),
	[check_id] smallint not null,
	[action_id] smallint not null,
	[action_attributes] xml,
	
	/*	primary key */
	constraint pk_sqlwatch_logger_check_action primary key clustered ([snapshot_time], [sql_instance], [check_id], [snapshot_type_id], [action_id]),

	/*	foreign key to logger to ensure deletion is applied when the parent record is removed */
	--constraint fk_sqlwatch_logger_check_action_logger_check foreign key (
	--	snapshot_time, sql_instance, check_id, snapshot_type_id
	--	) references [dbo].[sqlwatch_logger_check] (snapshot_time, sql_instance, check_id, snapshot_type_id) on delete cascade,

	/*	foreign key to config action to make sure we only reference valid action and to 
		delete any logger records when the action is deleted 
		
		This has to be detached from config tables as it would prevent importing into central repository
		without also importing config tables. RI is handled via trigger in [dbo].[sqlwatch_config_action] */
	--constraint fk_sqlwatch_logger_check_action_action foreign key ([sql_instance], [action_id])	
	--	references [dbo].[sqlwatch_config_check_action] ([check_id], [action_id]) on delete cascade
)	
go
