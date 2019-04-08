CREATE TABLE [dbo].[sqlwatch_logger_disk_utilisation_database]
(
	[database_name] sysname,
	[database_create_date] datetime,
	[database_size_bytes] bigint,
	[unallocated_space_bytes] bigint,
	[reserved_bytes] bigint,
	[data_bytes] bigint,
	[index_size_bytes] bigint,
	[unused_bytes] bigint,
	[log_size_total_bytes] bigint,
	[log_size_used_bytes] bigint,
	[snapshot_time] datetime,
	[snapshot_type_id] tinyint,
	[sql_instance] nvarchar(25) default @@SERVERNAME,
	constraint PK_logger_disk_util_database
		primary key clustered ([snapshot_time], [database_name]),
	constraint FK_logger_disk_util_database_database
		foreign key ([database_name],[database_create_date],[sql_instance])
		references [dbo].[sqlwatch_meta_database] ([database_name],[database_create_date],[sql_instance])
		on delete cascade,
	constraint FK_logger_disk_util_database_snapshot 
		foreign key ([snapshot_time],[snapshot_type_id],[sql_instance])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[snapshot_type_id],[sql_instance])
		on delete cascade
)
