CREATE TABLE [dbo].[sqlwatch_meta_table]
(
	[sql_instance] nvarchar(25) not null,
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int identity (-2147483648,1) not null,
	[table_name] nvarchar(128),
	[table_type] nvarchar(128),
	[date_added] datetime default getutcdate(),
	[date_updated] datetime,
	[date_deleted] datetime,
	constraint pk_sqlwatch_meta_database_table primary key clustered (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id]
		),
	constraint fk_sqlwatch_meta_table_database foreign key ([sql_instance],[sqlwatch_database_id]) references [dbo].[sqlwatch_meta_database] ([sql_instance],[sqlwatch_database_id]) on delete cascade
)
