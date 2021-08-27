CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_procedure_stats]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_database_id] smallint NOT NULL,
	[sqlwatch_procedure_id] int not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint NOT NULL, 
	[cached_time] datetime not NULL,
	[cached_time_utc] datetime NULL,
	[last_execution_time] datetime not NULL,
	[last_execution_time_utc] datetime NULL,
	[execution_count] real NULL,
	[total_worker_time] real NULL,
	[min_worker_time] real NULL,
	[max_worker_time] real NULL,
	[total_physical_reads] real NULL,
	[min_physical_reads] real NULL,
	[max_physical_reads] real NULL,
	[total_logical_writes] real NULL,
	[min_logical_writes] real NULL,
	[max_logical_writes] real NULL,
	[total_logical_reads] real NULL,
	[min_logical_reads] real NULL,
	[max_logical_reads] real NULL,
	[total_elapsed_time] real NULL,
	[min_elapsed_time] real NULL,
	[max_elapsed_time] real NULL,

	delta_worker_time real null,
	delta_physical_reads real null,
	delta_logical_writes real null,
	delta_logical_reads real null,
	delta_elapsed_time real null,
	delta_execution_count real null,

	constraint pk_sqlwatch_logger_perf_procedure_stats primary key clustered (
			  [sql_instance]
			, [sqlwatch_database_id]
			, [sqlwatch_procedure_id]
			, [snapshot_time]
			, [snapshot_type_id]
			, [cached_time]
	),

	constraint fk_sqlwatch_logger_perf_procedure_stats_snapshot_header
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[sql_instance],[snapshot_type_id])
		on delete cascade on update cascade,

	constraint fk_sqlwatch_logger_perf_procedure_stats_procedure
		foreign key ([sql_instance], [sqlwatch_database_id], [sqlwatch_procedure_id])
		references [dbo].[sqlwatch_meta_procedure] ([sql_instance], [sqlwatch_database_id], [sqlwatch_procedure_id])
		on delete cascade
)
