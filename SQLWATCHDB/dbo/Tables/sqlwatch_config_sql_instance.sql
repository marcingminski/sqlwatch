CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] nvarchar(25) default @@SERVERNAME,
	[hostname] nvarchar(25) null,
	[sql_port] smallint null,
	[sqlwatch_database_name] sysname default DB_NAME(),
	[environment] sysname default 'DEFAULT',
	[is_active] bit not null default 1,
	[last_collection_time] datetime null,
	[collection_status] varchar(50),
	[utc_offset_minutes] int default DATEDIFF(mi, GETUTCDATE(), GETDATE()),
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
	)
)
