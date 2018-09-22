CREATE TABLE [dbo].[logger_missing_indexes]
(
	[servername] sysname,
	[database_name] sysname,
	[database_create_date] datetime,
	[object_name] nvarchar(256),
	[snapshot_time] datetime,
	[index_handle] int,
	[last_user_seek] datetime,
	[unique_compiles] bigint,
	[user_seeks] bigint,
	[user_scans] bigint,
	[avg_total_user_cost] float,
	[avg_user_impact] float,
	[missing_index_def] nvarchar(4000),
	[snapshot_type_id] tinyint
	constraint pk_logger_missing_indexes primary key clustered (
		[snapshot_time], [database_name], [index_handle]
	),
	constraint fk_logger_missing_indexes_database 
		foreign key ([database_name],[database_create_date])
		references [dbo].[sql_perf_mon_database] ([database_name],[database_create_date])
		on delete cascade,
	constraint fk_logger_missing_indexes_snapshot_header
		foreign key ([snapshot_time],[snapshot_type_id])
		references [dbo].[sql_perf_mon_snapshot_header] ([snapshot_time],[snapshot_type_id])
		on delete cascade
)
