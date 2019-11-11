CREATE TABLE [dbo].[sqlwatch_config_check_action]
(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[check_id] smallint not null,
	[action_id] smallint not null,
	[action_every_failure] bit not null default 0, --whether to send email with every value change as long as its a fail. i.e. we may want to be alerted of every job failure rather than only the first one
	[action_recovery] bit not null default 1, --whether to send a "recovery" email after check has gone back to OK. just to let us know that there is nothing to worry anymore
	[action_repeat_period_minutes] smallint null, --how often to repeat the trigger i.e. if we are low on disk we may want a daily reminder, not just one alert
	[action_hourly_limit] tinyint not null default 2, --no more than 2 alerts per hour, of each alert
	[action_template_id] smallint not null,
	constraint pk_sqlwatch_config_check_action primary key clustered (
		[sql_instance], [check_id], [action_id]
	),
	constraint fk_sqlwatch_config_check_action_check foreign key ([sql_instance], [check_id])
		references [dbo].[sqlwatch_config_check] ([sql_instance], [check_id]) on delete cascade,
	constraint fk_sqlwatch_config_check_action_action foreign key ([action_id])
		references [dbo].[sqlwatch_config_action] ( [action_id] ) on delete cascade,
	constraint fk_sqlwatch_config_check_action_template foreign key ([action_template_id])
		references [dbo].[sqlwatch_config_check_action_template] ([action_template_id])
)
