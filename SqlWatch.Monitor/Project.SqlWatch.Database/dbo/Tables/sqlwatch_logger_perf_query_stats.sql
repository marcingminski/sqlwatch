CREATE TABLE [dbo].[sqlwatch_logger_perf_query_stats]
(
	[sql_instance] varchar(32) not null,
	[sqlwatch_query_hash] varbinary(16) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint NOT NULL, 

	[sql_handle] varbinary(64) NOT NULL,
	[plan_handle] varbinary(64) NOT NULL,
	[creation_time] datetime not NULL,
	[last_execution_time] datetime not NULL,
	[execution_count] real NULL,
	[total_worker_time] real NULL,
	[last_worker_time] real NULL,
	[min_worker_time] real NULL,
	[max_worker_time] real NULL,
	[total_physical_reads] real NULL,
	[last_physical_reads] real NULL,
	[min_physical_reads] real NULL,
	[max_physical_reads] real NULL,
	[total_logical_writes] real NULL,
	[last_logical_writes] real NULL,
	[min_logical_writes] real NULL,
	[max_logical_writes] real NULL,
	[total_logical_reads] real NULL,
	[last_logical_reads] real NULL,
	[min_logical_reads] real NULL,
	[max_logical_reads] real NULL,
	[total_elapsed_time] real NULL,
	[last_elapsed_time] real NULL,
	[min_elapsed_time] real NULL,
	[max_elapsed_time] real NULL,

	delta_worker_time real null,
	delta_physical_reads real null,
	delta_logical_writes real null,
	delta_logical_reads real null,
	delta_elapsed_time real null,

	total_rows real,
	last_rows real,
	min_rows real,
	max_rows real,
	total_dop real,
	last_dop real,
	min_dop real,
	max_dop real,
	total_grant_kb real,
	last_grant_kb real,
	min_grant_kb real,	
	max_grant_kb real,	
	total_used_grant_kb real,	
	last_used_grant_kb real,	
	min_used_grant_kb real,	
	max_used_grant_kb real,	
	total_ideal_grant_kb real,	
	last_ideal_grant_kb real,	
	min_ideal_grant_kb real,	
	max_ideal_grant_kb real,	
	total_reserved_threads real,	
	last_reserved_threads real,	
	min_reserved_threads real,	
	max_reserved_threads real,	
	total_used_threads real,	
	last_used_threads real,	
	min_used_threads real,	
	max_used_threads real,

	constraint pk_sqlwatch_logger_perf_query_stats primary key clustered (
			  [sql_instance]
			, [sqlwatch_query_hash]
			, [snapshot_time]
			, [snapshot_type_id]
			, [creation_time]
	),

	constraint fk_sqlwatch_logger_perf_query_stats_snapshot_header
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[sql_instance],[snapshot_type_id])
		on delete cascade on update cascade,

	constraint fk_sqlwatch_logger_perf_query_stats_query
		foreign key ([sql_instance], [sqlwatch_query_hash])
		references [dbo].[sqlwatch_meta_sql_query] ([sql_instance], [sqlwatch_query_hash])
		on delete cascade
)
