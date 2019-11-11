CREATE TABLE [dbo].[sqlwatch_config_check_action_template]
(
	[action_template_id] smallint identity(1,1) not null,
	[action_template_description] varchar(1024) null,
	[action_template_fail_subject] nvarchar(max) not null,
	[action_template_fail_body] nvarchar(max) not null,
	[action_template_repeat_subject] nvarchar(max) not null,
	[action_template_repeat_body] nvarchar(max) not null,
	[action_template_recover_subject] nvarchar(max) not null,
	[action_template_recover_body] nvarchar(max) not null,
	constraint pk_sqlwatch_config_action_template primary key clustered (
		[action_template_id]
	)
)
