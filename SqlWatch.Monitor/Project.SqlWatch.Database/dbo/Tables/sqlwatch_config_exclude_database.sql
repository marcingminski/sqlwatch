CREATE TABLE [dbo].[sqlwatch_config_exclude_database]
( 
	[database_name_pattern] nvarchar(128) not null,
	[snapshot_type_id] tinyint not null,
	constraint pk_sqlwatch_config_exclude_database primary key clustered (
		[database_name_pattern], [snapshot_type_id]
	),
	constraint fk_sqlwatch_config_logger_exclude_database_snapshot_type foreign key ([snapshot_type_id])
		references [dbo].[sqlwatch_config_snapshot_type] ([snapshot_type_id]) on delete cascade

)
