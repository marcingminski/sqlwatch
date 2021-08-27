CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_exec_procedure_stats]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin

	set nocount on;

    exec [dbo].[usp_sqlwatch_internal_meta_add_procedure]
    @xdoc = @xdoc,
    @sql_instance = @sql_instance;

	select 
		[ps].[cached_time]
		, [ps].[cached_time_utc]
		, [ps].[last_execution_time]
		, [ps].[last_execution_time_utc]
		, [ps].[execution_count]
		, [ps].[total_worker_time]
		, [ps].[last_worker_time]
		, [ps].[min_worker_time]
		, [ps].[max_worker_time]
		, [ps].[total_physical_reads]
		, [ps].[last_physical_reads]
		, [ps].[min_physical_reads]
		, [ps].[max_physical_reads]
		, [ps].[total_logical_writes]
		, [ps].[last_logical_writes]
		, [ps].[min_logical_writes]
		, [ps].[max_logical_writes]
		, [ps].[total_logical_reads]
		, [ps].[last_logical_reads]
		, [ps].[min_logical_reads]
		, [ps].[max_logical_reads]
		, [ps].[total_elapsed_time]
		, [ps].[last_elapsed_time]
		, [ps].[min_elapsed_time]
		, [ps].[max_elapsed_time]
		, [ps].[database_name]
		, [ps].[database_create_date]
		, [ps].[procedure_name]
		, [ps].[type]
		, sd.sqlwatch_database_id
		, p.sqlwatch_procedure_id
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_procedure_stats/row',1) 
		with (
			[cached_time] datetime2(3),
			[cached_time_utc] datetime2(3),
			[last_execution_time] datetime2(3),
			[last_execution_time_utc] datetime2(3),
			[execution_count] real,
			[total_worker_time] real,
			[last_worker_time] real,
			[min_worker_time] real,
			[max_worker_time] real,
			[total_physical_reads] real,
			[last_physical_reads] real,
			[min_physical_reads] real,
			[max_physical_reads] real,
			[total_logical_writes] real,
			[last_logical_writes] real,
			[min_logical_writes] real,
			[max_logical_writes] real,
			[total_logical_reads] real,
			[last_logical_reads] real,
			[min_logical_reads] real,
			[max_logical_reads] real,
			[total_elapsed_time] real,
			[last_elapsed_time] real,
			[min_elapsed_time] real,
			[max_elapsed_time] real, 
			[database_name] nvarchar(128),
			database_create_date datetime2(3),
			procedure_name nvarchar(256),
			type char(2)
		)ps

	inner join dbo.sqlwatch_meta_database sd
		on sd.database_name = ps.database_name collate database_default
		and sd.database_create_date = ps.database_create_date
		and sd.sql_instance = @sql_instance

	inner join dbo.sqlwatch_meta_procedure p
		on p.procedure_name = ps.procedure_name
		and p.sql_instance = @sql_instance
		and p.sqlwatch_database_id = sd.sqlwatch_database_id;


	insert into [dbo].[sqlwatch_logger_dm_exec_procedure_stats] (
			[cached_time] ,
			[last_execution_time] ,

			[execution_count] ,
			[total_worker_time] ,
			[min_worker_time] ,
			[max_worker_time] ,
			[total_physical_reads] ,
			[min_physical_reads] ,
			[max_physical_reads] ,
			[total_logical_writes] ,
			[min_logical_writes] ,
			[max_logical_writes] ,
			[total_logical_reads],
			[min_logical_reads] ,
			[max_logical_reads] ,
			[total_elapsed_time],
			[min_elapsed_time] ,
			[max_elapsed_time]

			,delta_worker_time
			,delta_physical_reads
			,delta_logical_writes
			,delta_logical_reads
			,delta_elapsed_time
			,delta_execution_count

			,[sql_instance]
			,[sqlwatch_database_id]
			,[sqlwatch_procedure_id]
			,[snapshot_time] 
			,[snapshot_type_id] 

			,[last_execution_time_utc]
			,[cached_time_utc]

	)
	select 
		  ps.cached_time	
		, PS.last_execution_time

		, execution_count=convert(real,ps.execution_count)
		, total_worker_time=convert(real,ps.total_worker_time)
		, min_worker_time=convert(real,ps.min_worker_time)
		, max_worker_time=convert(real,ps.max_worker_time)	
		, total_physical_reads=convert(real,ps.total_physical_reads)	
		, min_physical_reads=convert(real,ps.min_physical_reads)	
		, max_physical_reads=convert(real,ps.max_physical_reads)	
		, total_logical_writes=convert(real,ps.total_logical_writes)	
		, min_logical_writes=convert(real,ps.min_logical_writes)	
		, max_logical_writes=convert(real,ps.max_logical_writes)	
		, total_logical_reads=convert(real,ps.total_logical_reads)	
		, min_logical_reads=convert(real,ps.min_logical_reads)	
		, max_logical_reads=convert(real,ps.max_logical_reads)	
		, total_elapsed_time=convert(real,ps.total_elapsed_time)	
		, min_elapsed_time=convert(real,ps.min_elapsed_time)	
		, max_elapsed_time=convert(real,ps.max_elapsed_time)

		, delta_worker_time=convert(real,case when ps.total_worker_time > isnull(prev.total_worker_time,0) then ps.total_worker_time - isnull(prev.total_worker_time,0) else 0 end)
		, delta_physical_reads=convert(real,case when ps.total_physical_reads > isnull(prev.total_physical_reads,0) then ps.total_physical_reads - isnull(prev.total_physical_reads,0) else 0 end)
		, delta_logical_writes=convert(real,case when ps.total_logical_writes > isnull(prev.total_logical_writes,0) then ps.total_logical_writes - isnull(prev.total_logical_writes,0) else 0 end)
		, delta_logical_reads=convert(real,case when ps.total_logical_reads > isnull(prev.total_logical_reads,0) then ps.total_logical_reads - isnull(prev.total_logical_reads,0) else 0 end)
		, delta_elapsed_time=convert(real,case when ps.total_elapsed_time > isnull(prev.total_elapsed_time,0) then ps.total_elapsed_time - isnull(prev.total_elapsed_time,0) else 0 end)
		, delta_execution_count=convert(real,case when ps.execution_count> isnull(prev.execution_count,0) then ps.execution_count - isnull(prev.execution_count,0) else 0 end)

		, sql_instance = @sql_instance
		, ps.sqlwatch_database_id
		, ps.sqlwatch_procedure_id
		, snapshot_time = @snapshot_time
		, snapshot_type_id = @snapshot_type_id

		, ps.last_execution_time_utc
		, ps.cached_time_utc

	from #t ps (nolock)

	inner join dbo.sqlwatch_meta_procedure p
		on p.sql_instance = @sql_instance
		and p.sqlwatch_database_id = ps.sqlwatch_database_id
		and p.sqlwatch_procedure_id = ps.sqlwatch_procedure_id

	left join [dbo].[sqlwatch_config_exclude_procedure] ex
		on ps.database_name like ex.database_name_pattern
		and ps.procedure_name like ex.procedure_name_pattern
		and ex.snapshot_type_id = @snapshot_type_id

	left join [dbo].[sqlwatch_logger_dm_exec_procedure_stats] prev
		on prev.sql_instance = @sql_instance
		and prev.sqlwatch_database_id = ps.sqlwatch_database_id
		and prev.[sqlwatch_procedure_id] = ps.[sqlwatch_procedure_id]
		and prev.cached_time = ps.cached_time
		and prev.snapshot_time = p.last_usage_stats_snapshot_time

	where ps.type = 'P'
	and ex.snapshot_type_id is null
	and (
		ps.last_execution_time > prev.[last_execution_time]
		or prev.[last_execution_time] is null
	)

	option (keep plan);

	update p
		set last_usage_stats_snapshot_time = @snapshot_time
	from [dbo].[sqlwatch_meta_procedure] p
	inner join (
		select distinct 
			sqlwatch_database_id,
			sqlwatch_procedure_id
		from #t
		) t
		on t.sqlwatch_procedure_id = p.sqlwatch_procedure_id
		and t.sqlwatch_database_id = p.sqlwatch_database_id
		and p.sql_instance = @sql_instance
		;
end;