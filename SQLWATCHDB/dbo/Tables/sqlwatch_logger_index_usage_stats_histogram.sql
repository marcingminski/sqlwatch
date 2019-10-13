CREATE TABLE [dbo].[sqlwatch_logger_index_usage_stats_histogram] (
	[sqlwatch_database_id] smallint NOT NULL,
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
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	 constraint [pk_logger_index_stats_histogram] primary key nonclustered ([snapshot_time],[snapshot_type_id], [index_id] ASC,[sqlwatch_database_id], [object_name] ASC,[sqlwatch_stat_range_id] ASC, [sql_instance]),
	 constraint [fk_logger_index_stats_histogram_database] foreign key ([sql_instance], [sqlwatch_database_id]) references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id]) on delete cascade on update cascade,
	 constraint [fk_logger_index_stats_histogram] foreign key ([snapshot_time],[snapshot_type_id], [sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id], [sql_instance]) on delete cascade on update cascade
	 )
	 go

	 CREATE NONCLUSTERED INDEX idx_sqlwatch_index_histogram_001
ON [dbo].[sqlwatch_logger_index_usage_stats_histogram] ([sql_instance])
INCLUDE ([snapshot_time],[snapshot_type_id])