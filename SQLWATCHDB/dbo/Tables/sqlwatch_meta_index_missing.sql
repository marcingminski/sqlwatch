CREATE TABLE [dbo].[sqlwatch_meta_index_missing]
(
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int not null,
	[sqlwatch_missing_index_id] int identity (-2147483648,1),
	[equality_columns] nvarchar(max),
	[inequality_columns] nvarchar(max),
	[included_columns] nvarchar(max),
	[statement] nvarchar(max),
	[index_handle] int,
	[date_added] datetime default getutcdate(),
	[date_updated] datetime,
	[date_deleted] datetime,
	constraint pk_sqlwatch_meta_index_missing primary key (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_missing_index_id]
	),
	constraint fk_sqlwatch_meta_index_missing_table foreign key ([sql_instance], [sqlwatch_database_id],  [sqlwatch_table_id]) 
		references [dbo].[sqlwatch_meta_table] ([sql_instance], [sqlwatch_database_id],  [sqlwatch_table_id]) on delete cascade
)
