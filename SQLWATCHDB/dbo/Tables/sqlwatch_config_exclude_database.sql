CREATE TABLE [dbo].[sqlwatch_config_exclude_database]
(
	[database_name_pattern] nvarchar(128) not null,
	constraint pk_sqlwatch_config_exclude_database primary key clustered (
		[database_name_pattern]
	)
)
