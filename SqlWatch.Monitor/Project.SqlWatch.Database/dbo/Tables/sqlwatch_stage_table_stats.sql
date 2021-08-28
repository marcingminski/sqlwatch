CREATE TABLE [dbo].[sqlwatch_stage_table_stats]
(
	table_name nvarchar(512),
	[database_name] sysname,
	database_create_date datetime2(3),
	row_count real,
	total_pages real,
	used_pages real,
	[data_compression] bit,
	snapshot_time datetime2(0),
	snapshot_type_id tinyint,
	sql_instance varchar(32),

	constraint pk_sqlwatch_stage_table_stats primary key clustered (
		sql_instance, [database_name], table_name
	)
);
