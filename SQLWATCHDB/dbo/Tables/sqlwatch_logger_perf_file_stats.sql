CREATE TABLE [dbo].[sqlwatch_logger_perf_file_stats]
(
	[sqlwatch_database_id] smallint not null,
	--[database_create_date] datetime not null default '1900-01-01',
	[sqlwatch_master_file_id] smallint not null,
	[num_of_reads] real not null,
	[num_of_bytes_read] real not null,
	[io_stall_read_ms] real not null,
	[num_of_writes] real not null,
	[num_of_bytes_written] real not null,
	[io_stall_write_ms] real not null,
	[size_on_disk_bytes] real not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_perf_file_stats_type default (1) ,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_perf_file_stats_sql_instance default (@@SERVERNAME),

	[num_of_reads_delta] real null,
	[num_of_bytes_read_delta] real null,
	[io_stall_read_ms_delta] real null,
	[num_of_writes_delta] real null,
	[num_of_bytes_written_delta] real null,
	[io_stall_write_ms_delta] real null,
	[size_on_disk_bytes_delta] real null,
	[delta_seconds] int null,
	constraint fk_sqlwatch_logger_perf_file_stats_master_file foreign key ([sql_instance], [sqlwatch_database_id], [sqlwatch_master_file_id]) 
		references [dbo].[sqlwatch_meta_master_file] ([sql_instance], [sqlwatch_database_id], [sqlwatch_master_file_id]) on delete cascade,
	constraint fk_sql_perf_mon_file_stats_snapshot_header foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade on update cascade,
	constraint pk_sql_perf_mon_file_stats primary key clustered (
		[sql_instance], [snapshot_time], [sqlwatch_database_id], [sqlwatch_master_file_id], [snapshot_type_id]
	)
)
go

--CREATE NONCLUSTERED INDEX idx_sqlwatch_perf_file_stats_001
--ON [dbo].[sqlwatch_logger_perf_file_stats] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])
--GO

--CREATE NONCLUSTERED INDEX idx_sqlwatch_perf_file_stats_002
--ON [dbo].[sqlwatch_logger_perf_file_stats] ([sqlwatch_master_file_id],[sql_instance])
--INCLUDE ([sqlwatch_database_id],[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],[num_of_writes],[num_of_bytes_written],[io_stall_write_ms],[size_on_disk_bytes])