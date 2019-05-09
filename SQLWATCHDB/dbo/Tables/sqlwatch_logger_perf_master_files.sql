CREATE TABLE [dbo].[sqlwatch_logger_perf_master_files]
(
	[database_name] sysname,
	[database_create_date] datetime,
	[file_type] tinyint,
	[file_physical_name] nvarchar(260),
	[file_size] int,
	[snapshot_time] datetime,
	[snapshot_type_id] tinyint,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint PK_sql_perf_mon_master_files primary key clustered (
		[snapshot_time], [snapshot_type_id], [database_name], [database_create_date], [sql_instance]
		),
	constraint FK_sql_perf_mon_master_files_db foreign key ([database_name], [database_create_date], [sql_instance]) 
		references [dbo].[sqlwatch_meta_database](
			[database_name], [database_create_date], [sql_instance]
		) on delete cascade,
	constraint FK_sql_perf_mon_master_files_snapshot foreign key ([snapshot_time], [snapshot_type_id], [sql_instance])
		references [dbo].[sqlwatch_logger_snapshot_header] (
			[snapshot_time], [snapshot_type_id], [sql_instance]
		) on delete cascade on update cascade
)
