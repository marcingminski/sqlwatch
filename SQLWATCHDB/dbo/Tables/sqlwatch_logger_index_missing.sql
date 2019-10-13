CREATE TABLE [dbo].[sqlwatch_logger_index_missing]
(
	[servername] sysname,
	[sqlwatch_database_id] smallint,
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
	[snapshot_type_id] tinyint,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint pk_logger_missing_indexes primary key clustered (
		[snapshot_time], [snapshot_type_id], [sqlwatch_database_id], [index_handle], [sql_instance]
	),
	constraint fk_logger_missing_indexes_database 
		foreign key ([sql_instance], [sqlwatch_database_id])
		references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id])
		on delete cascade,
	constraint fk_logger_missing_indexes_snapshot_header
		foreign key ([snapshot_time],[snapshot_type_id],[sql_instance])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[snapshot_type_id],[sql_instance])
		on delete cascade on update cascade
)
go

CREATE NONCLUSTERED INDEX idx_sqlwatch_index_missing_001
ON [dbo].[sqlwatch_logger_index_missing] ([sql_instance])
INCLUDE ([snapshot_time],[snapshot_type_id])