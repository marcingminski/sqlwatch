CREATE TABLE [dbo].[sqlwatch_config_alert_check]
(
	[sql_instance] varchar(32) not null default @@SERVERNAME,
	[check_id] smallint identity (1,1) not null,
	[check_name] nvarchar(50) not null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) not null, --the sql query to execute to check for value, the return should be a one row one value which will be compared against thresholds. 
	[check_frequency_minutes] smallint null, --how often to run this check, by default the ALERT agent job runs every 2 minutes but we may not want to run all checks every 2 minutes.
	[check_threshold_warning] varchar(100) null,
	[check_threshold_critical] varchar(100) null,
	[check_enabled] bit not null default 1, --if enabled the check will be processed
	[target_id] smallint null, 
	[trigger_enabled] bit not null default 1, --if enabled a notification will be processed according to the notification rules.
	[trigger_every_fail] bit not null default 0, --whether to send email with every value change as long as its a fail. i.e. we may want to be alerted of every job failure rather than only the first one
	[trigger_recovery] bit not null default 1, --whether to send a "recovery" email after check has gone back to OK. just to let us know that there is nothing to worry anymore
	[trigger_repeat_period_minutes] smallint null, --how often to repeat the trigger i.e. if we are low on disk we may want a daily reminder, not just one alert
	[trigger_limit_hour] tinyint not null default 2, --no more than 2 alerts per hour, of each alert
	constraint pk_sqlwatch_config_alert_check primary key clustered (
		[sql_instance], [check_id]
		),
	constraint fk_sqlwatch_config_alert_rules_servername foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade,
	constraint fk_sqlwatch_config_alert_check_target foreign key ([target_id])
		references dbo.[sqlwatch_config_alert_target] ([target_id])
)
