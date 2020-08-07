CREATE TABLE [dbo].[sqlwatch_logger_index_histogram] (
	[sqlwatch_database_id] smallint not null,
	[sqlwatch_table_id] int not null,
	[sqlwatch_index_id] int not null,
	[sqlwatch_stat_range_id] bigint identity(1,1) not null,
	[RANGE_HI_KEY] nvarchar(max) NULL,
	[RANGE_ROWS] [real] NULL,
	[EQ_ROWS] [real] NULL,
	[DISTINCT_RANGE_ROWS] [real] NULL,
	[AVG_RANGE_ROWS] [real] NULL,
	[snapshot_time] datetime2(0) NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL,
	[collection_time] datetime,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_index_usage_stats_histogram_sql_instance default (@@SERVERNAME),
	 constraint [pk_logger_index_histogram] primary key nonclustered ([snapshot_time],[sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id], [sqlwatch_stat_range_id], [snapshot_type_id]),
	 constraint [fk_sqlwatch_logger_index_histogram_index] foreign key ([sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id]) 
		references [dbo].[sqlwatch_meta_index] ([sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [sqlwatch_index_id]) on delete cascade,
	 --constraint [fk_logger_index_stats_histogram_database] foreign key ([sql_instance], [sqlwatch_database_id]) references [dbo].[sqlwatch_meta_database] ([sql_instance], [sqlwatch_database_id]) on delete cascade on update cascade,
	 constraint [fk_logger_index_histogram] foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade on update cascade
	 )
	 go

--	 CREATE NONCLUSTERED INDEX idx_sqlwatch_index_histogram_001
--ON [dbo].[sqlwatch_logger_index_usage_stats_histogram] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])