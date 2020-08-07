CREATE TABLE [dbo].[sqlwatch_meta_master_file]
(
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_master_file_id] smallint identity(1,1),
	--[database_create_date] datetime,
	[file_id] int,
	[file_type] tinyint,
	[file_name] nvarchar(260),
	[file_physical_name] nvarchar(260),
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_master_file_sql_instance default (@@SERVERNAME),
	[date_last_seen] datetime null constraint df_sqlwatch_meta_master_file_last_seen default (getutcdate()),
	[logical_disk] varchar(260),
	[date_created] datetime not null constraint df_sqlwatch_meta_master_file_date_created default (getutcdate()),
	[is_record_deleted] bit
	constraint PK_sql_perf_mon_master_files primary key clustered (
		[sql_instance], [sqlwatch_database_id], [sqlwatch_master_file_id]
		),
	constraint FK_sql_perf_mon_master_files_db foreign key ([sql_instance],[sqlwatch_database_id]) 
		references [dbo].[sqlwatch_meta_database](
			[sql_instance],[sqlwatch_database_id]
		) on delete cascade,
)
