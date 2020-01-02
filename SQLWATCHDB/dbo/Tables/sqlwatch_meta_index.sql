CREATE TABLE [dbo].[sqlwatch_meta_index]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int not null,
	[sqlwatch_index_id] int identity(1,1) not null,
	[index_name] nvarchar(128),
	[index_id] int not null,
	[index_type_desc] nvarchar(128),
	[date_created] datetime not null constraint df_sqlwatch_meta_index_date_created default (getutcdate()),
	[date_updated] datetime,
	[date_last_seen] datetime null constraint df_sqlwatch_meta_index_last_seen default (getutcdate()),
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_index primary key clustered (
		[sql_instance],[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id]
		),
	constraint fk_sqlwatch_meta_index foreign key ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id]) 
		references [dbo].[sqlwatch_meta_table] ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id]) on delete cascade,
	constraint uq_sqlwatch_meta_index unique (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [index_name]
		)
)
