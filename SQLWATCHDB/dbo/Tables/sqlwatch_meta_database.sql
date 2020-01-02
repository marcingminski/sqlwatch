CREATE TABLE [dbo].[sqlwatch_meta_database]
(
	[database_name] nvarchar(128) not null,
	[database_create_date] datetime not null constraint df_sqlwatch_meta_database_db_create_data default ('1970-01-01'),
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_database_sql_instance default (@@SERVERNAME),
	[sqlwatch_database_id] smallint identity(1,1),
	[date_last_seen] datetime null constraint df_sqlwatch_meta_database_last_seen default (getutcdate()),
	/*	bring database config so we can process checks on central repository */
	[is_auto_close_on] bit null,
	[is_auto_shrink_on] bit null,
	[is_auto_update_stats_on] bit null,
	[user_access] tinyint null,
	[state] tinyint null,
	[snapshot_isolation_state] tinyint,
	[is_read_committed_snapshot_on] bit,
	[recovery_model] tinyint,
	[page_verify_option] tinyint,
	[date_updated] datetime null,
	[is_record_deleted] bit

	/*	primary key */
	constraint PK_database primary key clustered (
		[sql_instance], [sqlwatch_database_id]
	 ),

	 constraint uq_sqlwatch_meta_database unique (
		[sql_instance], [database_name], [database_create_date]
	 ),
	 constraint fk_sqlwatch_meta_database_server foreign key ([sql_instance]) 
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
GO

