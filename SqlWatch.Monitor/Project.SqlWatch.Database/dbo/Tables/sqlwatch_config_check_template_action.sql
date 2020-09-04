CREATE TABLE [dbo].[sqlwatch_config_check_template_action]
(

	[check_name] [nvarchar](255) not null,
	[action_id] smallint not null,
	[action_every_failure] bit not null, 
	[action_recovery] bit not null,
	[action_repeat_period_minutes] smallint null,
	[action_hourly_limit] tinyint not null, 
	[action_template_id] smallint not null,

	constraint pk_sqlwatch_config_check_template_action primary key clustered ([check_name], [action_id]),

	constraint fk_sqlwatch_config_check_template_action_check_name foreign key ([check_name])
		references [dbo].[sqlwatch_config_check_template] ([check_name]) on delete no action
)
