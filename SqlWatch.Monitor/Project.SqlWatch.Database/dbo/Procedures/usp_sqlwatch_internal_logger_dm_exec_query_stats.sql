CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_exec_query_stats]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as

begin
	set nocount on;

	declare @sqlwatch_sql_query_plan [dbo].[utype_sqlwatch_sql_query_plan];

	insert into @sqlwatch_sql_query_plan (
		query_hash,
		sql_text,
		database_name,
		database_create_date,
		procedure_name,
		query_plan,
		query_plan_hash
	)
	select 
		query_hash = convert(varbinary(8),query_hash,1),
		sql_statement,
		database_name,
		database_create_date,
		procedure_name,
		query_plan,
		query_plan_hash = convert(varbinary(8),query_plan_hash,1)
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_query_stats/row',1) 
		with (
			query_hash varchar(128),
			sql_statement nvarchar(max),
			database_name nvarchar(128),
			database_create_date datetime2(3),
			procedure_name nvarchar(512),
			query_plan nvarchar(max),
			query_plan_hash varchar(128)
		);

	exec [dbo].[usp_sqlwatch_internal_meta_add_sql_query]
		@sqlwatch_sql_query_plan = @sqlwatch_sql_query_plan,
		@sql_instance = @sql_instance;

	select 
		[qs].[last_execution_time]
		, [qs].[execution_count]
		, [qs].[total_worker_time]
		, [qs].[min_worker_time]
		, [qs].[max_worker_time]
		, [qs].[total_physical_reads]
		, [qs].[min_physical_reads]
		, [qs].[max_physical_reads]
		, [qs].[total_logical_writes]
		, [qs].[min_logical_writes]
		, [qs].[max_logical_writes]
		, [qs].[total_logical_reads]
		, [qs].[min_logical_reads]
		, [qs].[max_logical_reads]
		, [qs].[total_elapsed_time]
		, [qs].[min_elapsed_time]
		, [qs].[max_elapsed_time]
		, [qs].[total_clr_time]
		, [qs].[min_clr_time]
		, [qs].[max_clr_time]
		, [qs].[total_rows]
		, [qs].[min_rows]
		, [qs].[max_rows]
		, [qs].[total_dop]
		, [qs].[min_dop]
		, [qs].[max_dop]
		, [qs].[total_grant_kb]
		, [qs].[min_grant_kb]
		, [qs].[max_grant_kb]
		, [qs].[total_used_grant_kb]
		, [qs].[min_used_grant_kb]
		, [qs].[max_used_grant_kb]
		, [qs].[total_ideal_grant_kb]
		, [qs].[min_ideal_grant_kb]
		, [qs].[max_ideal_grant_kb]
		, [qs].[total_reserved_threads]
		, [qs].[min_reserved_threads]
		, [qs].[max_reserved_threads]
		, [qs].[total_used_threads]
		, [qs].[min_used_threads]
		, [qs].[max_used_threads]
		, [qs].[sql_statement]
		, [qs].[query_hash]
		, [qs].[plan_generation_num]
		, [qs].[database_name]
		, [qs].[database_create_date]
		, [qs].[procedure_name]
		, [qs].[last_execution_time_utc]
		, query_hash_bin = convert(varbinary(8),qs.query_hash,1)
		, db.sqlwatch_database_id
		, p.sqlwatch_procedure_id

		, qs.query_plan_hash_distinct_count
		, qs.plan_handle_distinct_count
		, qs.sql_handle_distinct_count

		, qs.query_plan_hash_total_count
		, qs.plan_handle_total_count
		, qs.sql_handle_total_count
		, qs.first_creation_time
		, qs.last_creation_time
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_query_stats/row',1) 
	with (
		[last_execution_time] datetime ,
		[execution_count] real ,
		[total_worker_time] real ,
		[min_worker_time] real ,
		[max_worker_time] real ,
		[total_physical_reads] real ,
		[min_physical_reads] real ,
		[max_physical_reads] real ,
		[total_logical_writes] real ,
		[min_logical_writes] real ,
		[max_logical_writes] real ,
		[total_logical_reads] real ,
		[min_logical_reads] real ,
		[max_logical_reads] real ,
		[total_elapsed_time] real ,
		[min_elapsed_time] real ,
		[max_elapsed_time] real ,

		total_clr_time	real ,
		min_clr_time	real ,
		max_clr_time	real ,

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
		sql_statement nvarchar(max),
		query_hash varchar(128), 
		plan_generation_num bigint,
		database_name nvarchar(128),
		database_create_date datetime2(3),
		procedure_name nvarchar(512),
		last_execution_time_utc datetime2(3),

		query_plan_hash_distinct_count int,
		plan_handle_distinct_count int,
		sql_handle_distinct_count int,

		query_plan_hash_total_count int,
		plan_handle_total_count int,
		sql_handle_total_count int,
		
		first_creation_time datetime2(3),
		last_creation_time datetime2(3)

	) qs

	inner join dbo.sqlwatch_meta_database db
		on db.sql_instance = @sql_instance collate database_default
		and db.database_name = qs.database_name collate database_default
		and db.database_create_date = qs.database_create_date

	inner join dbo.sqlwatch_meta_procedure p 
		on p.sql_instance = @sql_instance collate database_default
		and p.sqlwatch_database_id = db.sqlwatch_database_id
		and p.procedure_name = qs.procedure_name collate database_default;

	insert into [dbo].[sqlwatch_logger_dm_exec_query_stats] (
		[sql_instance] ,
		[snapshot_time] ,
		[snapshot_type_id]

		,query_hash
		,last_execution_time	

		,execution_count	
		,total_worker_time	
		,min_worker_time	
		,max_worker_time	
		,total_physical_reads	
		,min_physical_reads	
		,max_physical_reads	
		,total_logical_writes	
		,min_logical_writes	
		,max_logical_writes	
		,total_logical_reads	
		,min_logical_reads	
		,max_logical_reads	
		,total_clr_time	
		,min_clr_time	
		,max_clr_time	
		,total_elapsed_time	
		,min_elapsed_time	
		,max_elapsed_time	
		,total_rows	
		,min_rows	
		,max_rows	
		,total_dop	
		,min_dop	
		,max_dop	
		,total_grant_kb	
		,min_grant_kb	
		,max_grant_kb	
		,total_used_grant_kb	
		,min_used_grant_kb	
		,max_used_grant_kb	
		,total_ideal_grant_kb	
		,min_ideal_grant_kb	
		,max_ideal_grant_kb	
		,total_reserved_threads	
		,min_reserved_threads	
		,max_reserved_threads	
		,total_used_threads	
		,min_used_threads	
		,max_used_threads

		,delta_worker_time 
		,delta_physical_reads
		,delta_logical_writes
		,delta_logical_reads 
		,delta_elapsed_time 
		,delta_time_s

		,plan_generation_num
		,sqlwatch_database_id
		,sqlwatch_procedure_id
		,last_execution_time_utc

		, delta_plan_generation_num
		, delta_execution_count

		, query_plan_hash_distinct_count
		, plan_handle_distinct_count
		, sql_handle_distinct_count

		, query_plan_hash_total_count
		, plan_handle_total_count
		, sql_handle_total_count

		, first_creation_time
		, last_creation_time

	)
	select 
		[sql_instance] = @sql_instance ,
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id

		,query_hash = query_hash_bin
		--,query_plan_hash = convert(varbinary(8),qs.query_plan_hash,1)
		,qs.last_execution_time	

		,qs.execution_count
		,qs.total_worker_time
		,qs.min_worker_time
		,qs.max_worker_time	
		,qs.total_physical_reads	
		,qs.min_physical_reads	
		,qs.max_physical_reads	
		,qs.total_logical_writes	
		,qs.min_logical_writes	
		,qs.max_logical_writes	
		,qs.total_logical_reads	
		,qs.min_logical_reads	
		,qs.max_logical_reads	
		,qs.total_clr_time	
		,qs.min_clr_time	
		,qs.max_clr_time	
		,qs.total_elapsed_time	
		,qs.min_elapsed_time	
		,qs.max_elapsed_time	
		,qs.total_rows	
		,qs.min_rows	
		,qs.max_rows	
		,qs.total_dop	
		,qs.min_dop	
		,qs.max_dop	
		,qs.total_grant_kb	
		,qs.min_grant_kb	
		,qs.max_grant_kb	
		,qs.total_used_grant_kb	
		,qs.min_used_grant_kb	
		,qs.max_used_grant_kb	
		,qs.total_ideal_grant_kb	
		,qs.min_ideal_grant_kb	
		,qs.max_ideal_grant_kb	
		,qs.total_reserved_threads	
		,qs.min_reserved_threads	
		,qs.max_reserved_threads	
		,qs.total_used_threads	
		,qs.min_used_threads	
		,qs.max_used_threads

		, delta_worker_time = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_worker_time, qs.total_worker_time)
		, delta_physical_reads = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_physical_reads, qs.total_physical_reads)
		, delta_logical_writes = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_logical_writes, qs.total_logical_writes)
		, delta_logical_reads = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_logical_reads, qs.total_logical_reads)
		, delta_elapsed_time = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_elapsed_time, qs.total_elapsed_time)
		, delta_time_s = case when prev.snapshot_time is null then null else datediff(second, prev.snapshot_time,@snapshot_time) end

		, qs.plan_generation_num
		, qs.sqlwatch_database_id
		, qs.sqlwatch_procedure_id
		, qs.last_execution_time_utc

		, delta_plan_generation_num = [dbo].[ufn_sqlwatch_get_delta_value](prev.plan_generation_num, qs.plan_generation_num)
		, delta_execution_count = [dbo].[ufn_sqlwatch_get_delta_value](prev.execution_count, qs.execution_count)

		, qs.query_plan_hash_distinct_count
		, qs.plan_handle_distinct_count
		, qs.sql_handle_distinct_count

		, qs.query_plan_hash_total_count
		, qs.plan_handle_total_count
		, qs.sql_handle_total_count

		, qs.first_creation_time
		, qs.last_creation_time

	from #t qs

	inner join [dbo].[sqlwatch_meta_sql_query] sm
		on sm.query_hash = qs.query_hash_bin
		and sm.sql_instance = @sql_instance
		and sm.sqlwatch_database_id = qs.sqlwatch_database_id
		and sm.sqlwatch_procedure_id = qs.sqlwatch_procedure_id

	left join [dbo].[sqlwatch_logger_dm_exec_query_stats] prev (nolock)
		on prev.sql_instance = @sql_instance 
		and prev.snapshot_type_id = @snapshot_type_id
		and prev.query_hash = qs.query_hash
		--and prev.query_plan_hash= qs.query_plan_hash
		and prev.snapshot_time = sm.last_usage_stats_snapshot_time

	where qs.last_execution_time > prev.[last_execution_time]
		or prev.[last_execution_time] is null
	;

	update s
		set last_usage_stats_snapshot_time = @snapshot_time
	from [dbo].[sqlwatch_meta_sql_query] s
	inner join (
		select distinct 
			query_hash_bin,
			sqlwatch_database_id,
			sqlwatch_procedure_id
		from #t
		) t
		on s.query_hash = t.query_hash_bin
		and s.sql_instance = @sql_instance
		and s.sqlwatch_database_id = t.sqlwatch_database_id
		and s.sqlwatch_procedure_id = t.sqlwatch_procedure_id
		;

end;