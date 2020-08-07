CREATE TABLE [dbo].[sqlwatch_meta_index_missing]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_index_missing_sql_instance default (@@SERVERNAME),
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int not null,
	[sqlwatch_missing_index_id] int identity(1,1) not null,
	[equality_columns] nvarchar(max),
	[inequality_columns] nvarchar(max),
	[included_columns] nvarchar(max),
	[statement] nvarchar(max),
	[index_handle] int,
	[date_created] datetime not null constraint df_sqlwatch_meta_index_missing_date_created default (getutcdate()),
	[date_last_seen] datetime null constraint df_sqlwatch_meta_index_missing_last_seen default (getutcdate()),
	[is_record_deleted] bit
	constraint pk_sqlwatch_meta_index_missing primary key (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_missing_index_id]
	),
	constraint fk_sqlwatch_meta_index_missing_table foreign key ([sql_instance], [sqlwatch_database_id],  [sqlwatch_table_id]) 
		references [dbo].[sqlwatch_meta_table] ([sql_instance], [sqlwatch_database_id],  [sqlwatch_table_id]) on delete cascade
)
