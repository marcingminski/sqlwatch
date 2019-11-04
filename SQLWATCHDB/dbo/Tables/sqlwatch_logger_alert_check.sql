CREATE TABLE [dbo].[sqlwatch_logger_alert_check]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0),
	[snapshot_type_id] tinyint,
	[check_id] smallint not null,
	[check_result] real not null,
	[check_pass] bit not null,
	[alert_trigger] bit not null,
	[check_exec_time_ms] real null,
	constraint pk_sqlwatch_logger_alert primary key clustered (
		sql_instance, snapshot_time, check_id, snapshot_type_id
		),
	constraint fk_sqlwatch_logger_alert_rule foreign key ( sql_instance, check_id )
		references dbo.sqlwatch_config_alert_check (sql_instance, check_id) on delete cascade
)
