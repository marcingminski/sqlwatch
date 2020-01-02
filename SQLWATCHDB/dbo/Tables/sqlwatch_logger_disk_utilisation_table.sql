CREATE TABLE [dbo].[sqlwatch_logger_disk_utilisation_table]
(
	sqlwatch_database_id smallint not null,
	sqlwatch_table_id int not null,
	/* original types are 8 bytes bigint, we are using 4 bytes real to save space at a cost of small error rate due to approximation.
	   but it will make no big difference in rowcount and size */
	row_count real not null,
	total_pages real not null,
	used_pages real not null,
	data_compression tinyint,
	snapshot_type_id tinyint not null,
	snapshot_time datetime2(0) not null,
	sql_instance varchar(32) not null,
	row_count_delta real,
	total_pages_delta real,
	used_pages_delta real,

	constraint pk_sqlwatch_logger_disk_utilisation_table primary key clustered (
		[snapshot_time], [sql_instance], [snapshot_type_id], sqlwatch_database_id, sqlwatch_table_id
	),

	constraint fk_sqlwatch_logger_disk_utilisation_table_header foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references dbo.sqlwatch_logger_snapshot_header ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade,

	constraint fk_sqlwatch_logger_disk_utilistation_table_meta_table foreign key ([sql_instance], [sqlwatch_database_id], [sqlwatch_table_id])
		references dbo.sqlwatch_meta_table ([sql_instance], [sqlwatch_database_id], [sqlwatch_table_id]) on delete cascade

)
