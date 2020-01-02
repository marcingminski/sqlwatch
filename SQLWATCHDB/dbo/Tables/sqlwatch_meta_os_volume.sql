CREATE TABLE [dbo].[sqlwatch_meta_os_volume]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_os_volume_sql_instance default (@@SERVERNAME),
	[sqlwatch_volume_id] smallint identity(1,1) not null,
	[volume_name] nvarchar(255) not null,
	[label] nvarchar(255) not null,
	[file_system] varchar(255) not null,
	[volume_block_size_bytes] int,
	[date_created] datetime not null constraint df_sqlwatch_meta_os_volume_date_created default (getutcdate()),
	[date_updated] datetime null,
	[date_last_seen] datetime null,
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_os_volume primary key clustered (
		[sql_instance], [sqlwatch_volume_id]
		),
	constraint fk_sqlwatch_meta_os_volume_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
