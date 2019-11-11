CREATE TABLE [dbo].[sqlwatch_logger_check]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint default 18 not null,
	[check_id] smallint not null,
	[check_value] real not null,
	[check_status] varchar(50) not null,
	[check_exec_time_ms] real null,
	constraint pk_sqlwatch_logger_check primary key clustered (
		snapshot_time, sql_instance, check_id, snapshot_type_id
		),
	constraint fk_sqlwatch_logger_check_rule foreign key ( sql_instance, check_id )
		references dbo.[sqlwatch_config_check] (sql_instance, check_id) on delete cascade
)
go