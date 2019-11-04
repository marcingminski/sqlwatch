CREATE TABLE [dbo].[sqlwatch_config_alert_target]
(
	[target_id] smallint identity(1,1) not null,
	[target_type] varchar(50) not null default 'sp_send_dbmail',
	[target_address] varchar(255) not null default 'dba@company.com',
	[target_attributes] varchar(255) null,
	constraint pk_sqlwatch_config_alert_target primary key clustered (
		[target_id]
		)
)
