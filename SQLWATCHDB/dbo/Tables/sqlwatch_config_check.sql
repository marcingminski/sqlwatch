CREATE TABLE [dbo].[sqlwatch_config_check]
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
	constraint pk_sqlwatch_config_alert_check primary key clustered (
		[sql_instance], [check_id]
		),
	constraint fk_sqlwatch_config_alert_rules_servername foreign key ([sql_instance])
		references dbo.sqlwatch_meta_server ([servername]) on delete cascade,
	constraint chk_sqlwatch_config_check_thresholds check (
				([check_threshold_warning] is not null and [check_threshold_critical] is not null)
			or	([check_threshold_warning] is null and [check_threshold_critical] is not null)
		)
)
