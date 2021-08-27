CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_query_stats]
(
	[sql_instance] varchar(32) not null,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint NOT NULL, 
	
	query_hash varbinary(8) not null,
	--query_plan_hash varbinary(8) not null,
	query_plan_hash_distinct_count int,
	plan_handle_distinct_count int,
	sql_handle_distinct_count int,

	[last_execution_time] datetime not NULL,
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

	total_clr_time	real null,
	min_clr_time	real null,
	max_clr_time	real null,

	total_rows real,
	min_rows real,
	max_rows real,
	total_dop real,
	min_dop real,
	max_dop real,
	total_grant_kb real,
	min_grant_kb real,	
	max_grant_kb real,	
	total_used_grant_kb real,	
	min_used_grant_kb real,	
	max_used_grant_kb real,	
	total_ideal_grant_kb real,	
	min_ideal_grant_kb real,	
	max_ideal_grant_kb real,	
	total_reserved_threads real,	
	min_reserved_threads real,	
	max_reserved_threads real,	
	total_used_threads real,	
	min_used_threads real,	
	max_used_threads real,

	delta_time_s int,

	plan_generation_num bigint,
	sqlwatch_database_id smallint,
	sqlwatch_procedure_id int,
	last_execution_time_utc datetime2(3),

	delta_plan_generation_num bigint,
	delta_execution_count real,

	query_plan_hash_total_count int,
	plan_handle_total_count int,
	sql_handle_total_count int,

	first_creation_time datetime2(3),
	last_creation_time datetime2(3),

	constraint pk_sqlwatch_logger_perf_query_stats primary key clustered (
			[sql_instance],
			[snapshot_time],
			[snapshot_type_id], 
			query_hash,
			--query_plan_hash,
			last_execution_time,
			sqlwatch_database_id,
			sqlwatch_procedure_id
	),

	constraint fk_sqlwatch_logger_perf_query_stats_snapshot_header
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time],[sql_instance],[snapshot_type_id])
		on delete cascade on update cascade,

	constraint fk_sqlwatch_logger_dm_exec_query_stats_sql_statement
		foreign key ([sql_instance], query_hash, sqlwatch_database_id, sqlwatch_procedure_id)
		references dbo.[sqlwatch_meta_sql_query] ([sql_instance], query_hash, sqlwatch_database_id, sqlwatch_procedure_id) 
		on delete cascade
);
go

create nonclustered index [idx_sqlwatch_logger_dm_exec_query_stats_01]
	on [dbo].[sqlwatch_logger_dm_exec_query_stats] ([sql_instance],[sqlwatch_database_id],[sqlwatch_procedure_id],[last_execution_time_utc])
	include ([query_hash],[execution_count],[total_worker_time]);
go