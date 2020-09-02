CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_query_stats]
as

begin
	set nocount on;
	set xact_abort on;

	declare @snapshot_type_id smallint = 28,
			@snapshot_time datetime2(0),
			@date_snapshot_previous datetime2(0)

	select @date_snapshot_previous = max([snapshot_time])
	from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
	where snapshot_type_id = @snapshot_type_id
	and sql_instance = [dbo].[ufn_sqlwatch_get_servername]()

	select 
		  sql_instance
		, [sqlwatch_query_hash]
		, total_worker_time
		, total_physical_reads
		, total_logical_writes
		, total_logical_reads
		, total_elapsed_time
		, creation_time
		, last_execution_time
	into #t
	from [dbo].[sqlwatch_logger_perf_query_stats]
	where sql_instance = [dbo].[ufn_sqlwatch_get_servername]() 
	and snapshot_type_id = @snapshot_type_id
	and snapshot_time = @date_snapshot_previous;

	create unique clustered index icx_tmp_query_stats_prev on #t (sql_instance,sqlwatch_query_hash,creation_time);

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id	

	select qs.*
	into #s
	from sys.dm_exec_query_stats qs	
	where last_execution_time > isnull((
		select max(last_execution_time) from #t
		),'1970-01-01')

	select 
		[sql_instance] = [dbo].[ufn_sqlwatch_get_servername](),
		[sqlwatch_query_hash] = hashbytes('MD5',query_hash),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id, 

		 qs.[sql_handle]
		,qs.plan_handle	
		,qs.creation_time	
		,qs.last_execution_time	

		,qs.execution_count	
		,qs.total_worker_time	
		,qs.last_worker_time	
		,qs.min_worker_time	
		,qs.max_worker_time	
		,qs.total_physical_reads	
		,qs.last_physical_reads	
		,qs.min_physical_reads	
		,qs.max_physical_reads	
		,qs.total_logical_writes	
		,qs.last_logical_writes	
		,qs.min_logical_writes	
		,qs.max_logical_writes	
		,qs.total_logical_reads	
		,qs.last_logical_reads	
		,qs.min_logical_reads	
		,qs.max_logical_reads	
		,qs.total_clr_time	
		,qs.last_clr_time	
		,qs.min_clr_time	
		,qs.max_clr_time	
		,qs.total_elapsed_time	
		,qs.last_elapsed_time	
		,qs.min_elapsed_time	
		,qs.max_elapsed_time	
		,qs.query_hash	
		,qs.query_plan_hash	
		,qs.total_rows	
		,qs.last_rows	
		,qs.min_rows	
		,qs.max_rows	
		,qs.total_dop	
		,qs.last_dop	
		,qs.min_dop	
		,qs.max_dop	
		,qs.total_grant_kb	
		,qs.last_grant_kb	
		,qs.min_grant_kb	
		,qs.max_grant_kb	
		,qs.total_used_grant_kb	
		,qs.last_used_grant_kb	
		,qs.min_used_grant_kb	
		,qs.max_used_grant_kb	
		,qs.total_ideal_grant_kb	
		,qs.last_ideal_grant_kb	
		,qs.min_ideal_grant_kb	
		,qs.max_ideal_grant_kb	
		,qs.total_reserved_threads	
		,qs.last_reserved_threads	
		,qs.min_reserved_threads	
		,qs.max_reserved_threads	
		,qs.total_used_threads	
		,qs.last_used_threads	
		,qs.min_used_threads	
		,qs.max_used_threads

	from #s

	--;merge [dbo].[sqlwatch_meta_sql_query] as target
	--using (
	--	select distinct 		  
	--		  t.text
	--	from #s
	--	cross apply sys.dm_exec_sql_text(s.sql_handle) t
	--
	--
	--
	--	from (
	--		select distinct [sqlwatch_query_hash]
	--		from [dbo].[sqlwatch_logger_perf_query_stats]
	--		where snapshot_time = @snapshot_time
	--		) s
	--	cross apply sys.dm_exec_sql_text(s.sql_handle) t
	--	where t.text is not null
	--)
end
