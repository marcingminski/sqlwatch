CREATE TABLE [dbo].[sqlwatch_meta_system_configuration]
(
	[sqlwatch_configuration_id] smallint identity(1,1) not null,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_system_configuration_sql_instance default (@@SERVERNAME),
	[configuration_id] int not null,
	[name] nvarchar(128) not null,
	[description] nvarchar(512) not null,
	[value] int not null,
	[value_in_use] int,
	[date_created] datetime not null constraint df_sqlwatch_meta_system_configuration_date_created default (getutcdate()),
	[date_updated] datetime null,
	[date_last_seen] datetime null,
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_system_configuration primary key clustered (
		[sql_instance], [sqlwatch_configuration_id]
		),
	constraint fk_sqlwatch_meta_system_configuration foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
