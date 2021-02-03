CREATE TABLE [dbo].[sqlwatch_config_check_template]
(
	[check_template_id] smallint identity(1,1),
	[check_name] nvarchar(255) not null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) not null, --the sql query to execute to check for value, the return should be a one row one value which will be compared against thresholds. 
	[check_frequency_minutes] smallint null, --how often to run this check, by default the ALERT agent job runs every 2 minutes but we may not want to run all checks every 2 minutes.
	[check_threshold_warning] varchar(100) null, --warning is optional
	[check_threshold_critical] varchar(100) not null, --critical is not optional
	[check_enabled] bit not null default 1, --if enabled the check will be processed
	[ignore_flapping] bit not null constraint df_sqlwatch_config_check_template_flapping default (0),
	[expand_by] varchar(50) null constraint chk_sqlwatch_config_check_template_expand_by check ([expand_by] in ('Database','Job','Disk')),
	[user_modified] bit not null,
	[template_enabled] bit

	constraint pk_sqlwatch_config_check_template primary key clustered ([check_name])
)
