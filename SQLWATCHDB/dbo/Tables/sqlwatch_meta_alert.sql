CREATE TABLE [dbo].[sqlwatch_meta_alert]
(
	[sql_instance] varchar(32) not null,
	[check_id] smallint not null,
	[last_check_date] datetime null,
	[last_check_value] real null,
	[last_check_status] varchar(50) null,
	[last_status_change_date] datetime null,
	[last_trigger_date] datetime null,
	constraint pk_sqlwatch_meta_alert primary key clustered (
		[sql_instance], [check_id]
		),
	constraint fk_sqlwatch_meta_alert_check foreign key ([sql_instance], [check_id])
		references [dbo].[sqlwatch_config_alert_check] ([sql_instance], [check_id]) on delete cascade
)
