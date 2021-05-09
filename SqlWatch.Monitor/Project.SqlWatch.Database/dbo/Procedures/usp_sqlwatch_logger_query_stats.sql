CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_query_stats]
as

begin
	set nocount on;
	set xact_abort on;

	declare @snapshot_type_id smallint = 28,
			@snapshot_time datetime2(0),
			@date_snapshot_previous datetime2(0),
			@sql_instance varchar(32) = [dbo].[ufn_sqlwatch_get_servername]();

	select @date_snapshot_previous = max([snapshot_time])
	from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
	where snapshot_type_id = @snapshot_type_id
	and sql_instance = @sql_instance ;

	select 
		  [sql_instance]
		, plan_handle
		, statement_start_offset
		, statement_end_offset
		, total_worker_time
		, total_physical_reads
		, total_logical_writes
		, total_logical_reads
		, total_elapsed_time
		, creation_time
		, last_execution_time
		, snapshot_time
	into #t
	from [dbo].[sqlwatch_logger_perf_query_stats]
	where sql_instance = @sql_instance 
	and snapshot_type_id = @snapshot_type_id
	and snapshot_time = @date_snapshot_previous;

	create unique clustered index icx_tmp_query_stats_prev on #t ([sql_instance],plan_handle,statement_start_offset, statement_end_offset, [creation_time]);

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id	

	select qs.*
	into #s
	from sys.dm_exec_query_stats qs	

	cross apply sys.dm_exec_text_query_plan([plan_handle], [statement_start_offset], [statement_end_offset]) qp

	where last_execution_time > isnull((
		select max(last_execution_time) from #t
		),'1970-01-01')

	--not stored procedures as we're collecting stored procedures elsewhere.
	and qp.objectid is null ;

	--normalise query text and plans
	declare @plan_handle_table dbo.utype_plan_handle;

	insert into @plan_handle_table (plan_handle, statement_start_offset, statement_end_offset )
	select distinct plan_handle,  statement_start_offset, statement_end_offset
	from #s
	;

	declare @sqlwatch_plan_id dbo.utype_plan_id
	insert into @sqlwatch_plan_id 
	exec [dbo].[usp_sqlwatch_internal_get_query_plans]
		@plan_handle = @plan_handle_table, 
		@sql_instance = @sql_instance
	;


	insert into [dbo].[sqlwatch_logger_perf_query_stats] (
		[sql_instance] ,
		[snapshot_time] ,
		[snapshot_type_id]

		,plan_handle
		,statement_start_offset
		,statement_end_offset
		,creation_time	
		,last_execution_time	

		,execution_count	
		,total_worker_time	
		,last_worker_time	
		,min_worker_time	
		,max_worker_time	
		,total_physical_reads	
		,last_physical_reads	
		,min_physical_reads	
		,max_physical_reads	
		,total_logical_writes	
		,last_logical_writes	
		,min_logical_writes	
		,max_logical_writes	
		,total_logical_reads	
		,last_logical_reads	
		,min_logical_reads	
		,max_logical_reads	
		,total_clr_time	
		,last_clr_time	
		,min_clr_time	
		,max_clr_time	
		,total_elapsed_time	
		,last_elapsed_time	
		,min_elapsed_time	
		,max_elapsed_time	
		,total_rows	
		,last_rows	
		,min_rows	
		,max_rows	
		,total_dop	
		,last_dop	
		,min_dop	
		,max_dop	
		,total_grant_kb	
		,last_grant_kb	
		,min_grant_kb	
		,max_grant_kb	
		,total_used_grant_kb	
		,last_used_grant_kb	
		,min_used_grant_kb	
		,max_used_grant_kb	
		,total_ideal_grant_kb	
		,last_ideal_grant_kb	
		,min_ideal_grant_kb	
		,max_ideal_grant_kb	
		,total_reserved_threads	
		,last_reserved_threads	
		,min_reserved_threads	
		,max_reserved_threads	
		,total_used_threads	
		,last_used_threads	
		,min_used_threads	
		,max_used_threads

		,delta_worker_time 
		,delta_physical_reads
		,delta_logical_writes
		,delta_logical_reads 
		,delta_elapsed_time 
		,delta_time_s
	)
	select 
		[sql_instance] = @sql_instance ,
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type_id

		,qs.plan_handle
		,qs.[statement_start_offset]
		,qs.[statement_end_offset]
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

		, delta_worker_time = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_worker_time, qs.total_worker_time)
		, delta_physical_reads = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_physical_reads, qs.total_physical_reads)
		, delta_logical_writes = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_logical_writes, qs.total_logical_writes)
		, delta_logical_reads = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_logical_reads, qs.total_logical_reads)
		, delta_elapsed_time = [dbo].[ufn_sqlwatch_get_delta_value](prev.total_elapsed_time, qs.total_elapsed_time)
		, delta_time_s = case when prev.snapshot_time is null then null else datediff(second, prev.snapshot_time,@snapshot_time) end

	from #s qs

	left join #t prev
		on prev.[sql_instance] = @sql_instance
		and prev.plan_handle = qs.plan_handle
		and prev.statement_start_offset = qs.statement_start_offset
		and prev.statement_end_offset = qs.statement_end_offset
		and prev.[creation_time] = qs.creation_time;
end;