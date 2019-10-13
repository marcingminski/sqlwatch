CREATE TABLE [dbo].[sqlwatch_logger_index_usage_stats]
(
	[sqlwatch_database_id] [smallint] NOT NULL,
	[object_name] [nvarchar](256) NOT NULL,
	[index_id] [int] NOT NULL,
	[index_name] [sysname] NULL,
	[used_pages_count] [bigint] NULL,
	[index_type] [tinyint] NOT NULL,
	[user_seeks] [bigint] NOT NULL,
	[user_scans] [bigint] NOT NULL,
	[user_lookups] [bigint] NOT NULL,
	[user_updates] [bigint] NOT NULL,
	[last_user_seek] [datetime] NULL,
	[last_user_scan] [datetime] NULL,
	[last_user_lookup] [datetime] NULL,
	[last_user_update] [datetime] NULL,
	[stats_date] [datetime] NULL,
	[snapshot_time] [datetime] NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL,
	[index_disabled] bit null,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	[partition_id] bigint not null default 0, --so we can add a column in previous versions of sqlwatch versions without having to backfill partition_ids
	constraint [pk_index_usage_stats] primary key clustered ([snapshot_time], [snapshot_type_id], [sqlwatch_database_id], [object_name] asc,[index_id] asc, [sql_instance], [partition_id]),
	constraint [fk_index_usage_stats_database] foreign key ([sql_instance], [sqlwatch_database_id]) references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id]) on delete cascade on update cascade,
	constraint [fk_index_usage_stats_header] foreign key ([snapshot_time],[snapshot_type_id], [sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id], [sql_instance]) on delete cascade on update cascade
)
go

CREATE NONCLUSTERED INDEX idx_sqlwatch_index_usage_stats_001
ON [dbo].[sqlwatch_logger_index_usage_stats] ([sql_instance])
INCLUDE ([snapshot_time],[snapshot_type_id])