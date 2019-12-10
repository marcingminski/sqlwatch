CREATE TABLE [dbo].[sqlwatch_logger_index_usage_stats]
(
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int not null,
	[sqlwatch_index_id] int not null,
	[used_pages_count] real NULL,
	[user_seeks] real NOT NULL,
	[user_scans] real NOT NULL,
	[user_lookups] real NOT NULL,
	[user_updates] real NOT NULL,
	[last_user_seek] [datetime] NULL,
	[last_user_scan] [datetime] NULL,
	[last_user_lookup] [datetime] NULL,
	[last_user_update] [datetime] NULL,
	[stats_date] [datetime] NULL,
	[snapshot_time] datetime2(0) NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL,
	[index_disabled] bit null,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_index_usage_stats_sql_instance default (@@SERVERNAME),
	[partition_id] bigint not null default 0, --so we can add a column in previous versions of sqlwatch versions without having to backfill partition_ids

	[used_pages_count_delta] real null,
	[user_seeks_delta] real null,
	[user_scans_delta] real null,
	[user_updates_delta] real null,
	[delta_seconds] int null,
	[user_lookups_delta] real null,
	[partition_count] real null, 
	[partition_count_delta] real null,
	constraint [pk_index_usage_stats] primary key clustered ([snapshot_time], [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [partition_id], [snapshot_type_id]),
	--constraint [fk_index_usage_stats_database] foreign key ([sql_instance], [sqlwatch_database_id]) references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id]) on delete cascade on update cascade,
	--constraint fk_sqlwatch_logger_index_usage_stats_table foreign key ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id]) 
	--	references [dbo].[sqlwatch_meta_table] ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id]) on delete cascade,
	constraint [fk_index_usage_stats_header] foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade on update cascade,
	constraint fk_sqlwatch_logger_index_usage_stats_index foreign key ([sql_instance],[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id])
		references [dbo].[sqlwatch_meta_index] ([sql_instance],[sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id]) on delete cascade

)
go

--CREATE NONCLUSTERED INDEX idx_sqlwatch_index_usage_stats_001
--ON [dbo].[sqlwatch_logger_index_usage_stats] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])