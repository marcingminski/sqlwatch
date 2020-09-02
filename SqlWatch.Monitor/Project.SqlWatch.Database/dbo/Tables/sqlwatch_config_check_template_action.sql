CREATE TABLE [dbo].[sqlwatch_config_check_template_action]
(
	[check_template_id] smallint not null,
	[action_id] smallint not null,
	[action_every_failure] bit not null, 
	[action_recovery] bit not null,
	[action_repeat_period_minutes] smallint null,
	[action_hourly_limit] tinyint not null, 
	[action_template_id] smallint not null,

	constraint pk_sqlwatch_config_check_template_action primary key clustered ([check_template_id], [action_id])
)
