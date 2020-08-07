CREATE TABLE [dbo].[sqlwatch_logger_disk_utilisation_database]
(
	[sqlwatch_database_id] smallint not null ,
	[database_size_bytes] bigint,
	[unallocated_space_bytes] bigint,
	[reserved_bytes] bigint,
	[data_bytes] bigint,
	[index_size_bytes] bigint,
	[unused_bytes] bigint,
	[log_size_total_bytes] bigint,
	[log_size_used_bytes] bigint,
	[snapshot_time] datetime2(0),
	[snapshot_type_id] tinyint,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_disk_utilisation_database_sql_instance default (@@SERVERNAME),
	
	--https://github.com/marcingminski/sqlwatch/issues/165
	[unallocated_extent_page_count] bigint null,
	[allocated_extent_page_count] bigint null,
	[version_store_reserved_page_count] bigint null,
	[user_object_reserved_page_count] bigint null,
	[internal_object_reserved_page_count] bigint null,
	[mixed_extent_page_count] bigint null,

	constraint PK_logger_disk_util_database
		primary key clustered ([snapshot_time],[snapshot_type_id],[sql_instance], [sqlwatch_database_id]),
	constraint FK_logger_disk_util_database_database
		foreign key ([sql_instance],[sqlwatch_database_id])
		references [dbo].[sqlwatch_meta_database] ([sql_instance],[sqlwatch_database_id])
		on delete cascade,
	constraint FK_logger_disk_util_database_snapshot 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[sql_instance],[snapshot_type_id])
		on delete cascade on update cascade
)
go

--CREATE NONCLUSTERED INDEX idx_sqlwatch_disk_util_database_001
--ON [dbo].[sqlwatch_logger_disk_utilisation_database] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])