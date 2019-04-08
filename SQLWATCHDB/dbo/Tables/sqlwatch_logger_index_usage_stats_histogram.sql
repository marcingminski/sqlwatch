CREATE TABLE [dbo].[sqlwatch_logger_index_usage_stats_histogram] (
	[database_name] [sysname] NOT NULL,
	[database_create_date] [datetime] NULL,
	[object_name] [nvarchar](256) NOT NULL,
	[index_name] [sysname] NULL,
	[index_id] [int] NOT NULL,
	[sqlwatch_stat_range_id] [bigint] IDENTITY(-9223372036854775808,1) NOT NULL,
	[RANGE_HI_KEY] [sql_variant] NULL,
	[RANGE_ROWS] [real] NULL,
	[EQ_ROWS] [real] NULL,
	[DISTINCT_RANGE_ROWS] [real] NULL,
	[AVG_RANGE_ROWS] [real] NULL,
	[snapshot_time] [datetime] NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL,
	[collection_time] datetime,
	 constraint [pk_logger_index_stats_histogram] primary key nonclustered ([snapshot_time] ASC,[index_id] ASC,[database_name] ASC,[object_name] ASC,[sqlwatch_stat_range_id] ASC),
	 constraint [fk_logger_index_stats_histogram] foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade
	 )