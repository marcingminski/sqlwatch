CREATE TABLE [dbo].[logger_index_usage_stats]
(
	[database_name] [sysname] NOT NULL,
	[database_create_date] [datetime] NOT NULL,
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
	constraint [pk_index_usage_stats] primary key clustered ([snapshot_time] asc,[database_name] asc,[object_name] asc,[index_id] asc),
	constraint [fk_index_usage_stats] foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade
)
