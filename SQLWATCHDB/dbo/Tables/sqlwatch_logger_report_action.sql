CREATE TABLE [dbo].[sqlwatch_logger_report_action]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_report_action_type default (18),
	[report_id] smallint not null,
	[action_id] smallint not null,
	constraint pk_sqlwatch_logger_report_action_action primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id], [report_id], [action_id]
	),
	/* replaced by trigger on config we can "detach it" and send to central repo */
	--constraint fk_sqlwatch_logger_report_action_action foreign key ([action_id])	
	--	references [dbo].[sqlwatch_config_action] ([action_id])

	--constraint fk_sqlwatch_logger_report_action_report foreign key ([report_id])
	--	references [dbo].[sqlwatch_config_report] ([report_id]) on delete cascade
)
