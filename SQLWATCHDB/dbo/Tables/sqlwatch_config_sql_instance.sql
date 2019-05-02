CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] nvarchar(25) default @@SERVERNAME,
	[hostname] nvarchar(25) null,
	[sql_port] smallint null,
	[is_active] bit not null default 1,
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
	)
)
