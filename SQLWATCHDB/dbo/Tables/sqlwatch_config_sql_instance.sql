CREATE TABLE [dbo].[sqlwatch_config_sql_instance]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_config_sql_instance_sql_instance default (@@SERVERNAME),
	[hostname] nvarchar(25) null,
	[sql_port] smallint null,
	[sqlwatch_database_name] sysname not null constraint df_sqlwatch_config_sql_instance_database_name default (DB_NAME()),
	[environment] sysname not null constraint df_sqlwatch_config_sql_instance_env default ('DEFAULT'),
	[is_active] bit not null constraint df_sqlwatch_config_sql_instance default (1),
	[last_collection_time] datetime null,
	[collection_status] varchar(50),
	constraint pk_config_sql_instance primary key clustered (
		[sql_instance]
	)
)
