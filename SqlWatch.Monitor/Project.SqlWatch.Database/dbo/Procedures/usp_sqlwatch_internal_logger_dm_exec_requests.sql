CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_exec_requests]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@timezoneoffset int
as
begin
	set nocount on;

	declare @sqlwatch_sql_query_plan as [dbo].[utype_sqlwatch_sql_query_plan];

	--requests stats
	insert into [dbo].[sqlwatch_logger_dm_exec_requests_stats] (
		[type] 
		,background 
		,running 
		,runnable
		,sleeping
		,suspended
		,wait_time
		,cpu_time 
		,waiting_tasks 
		,waiting_tasks_wait_duration_ms 

		,snapshot_time 
		,snapshot_type_id 
		,sql_instance 

		,backups_in_progress
	)
	select
		[type] = case when session_id > 50 then 1 else 0 end
	, [background] = convert(real,sum(case when isnull(status,'') collate database_default = 'Background' then 1 else 0 end))
	, [running] = convert(real,sum(case when isnull(status,'') collate database_default = 'Running' and session_id <> @@SPID then 1 else 0 end))
	, [runnable] = convert(real,sum(case when isnull(status,'') collate database_default = 'Runnable' then 1 else 0 end))
	, [sleeping] = convert(real,sum(case when isnull(status,'') collate database_default = 'Sleeping' then 1 else 0 end))
	, [suspended] = convert(real,sum(case when isnull(status,'') collate database_default = 'Suspended' then 1 else 0 end))
	, [wait_time] = sum(convert(real,wait_time))
	, [cpu_time] = sum(convert(real,cpu_time))
	, [waiting_tasks] = isnull(sum(waiting_tasks),0)
	, waiting_tasks_wait_duration_ms = null
	,snapshot_time = @snapshot_time
	,snapshot_type_id = @snapshot_type_id
	,sql_instance = @sql_instance
	,backup_commands = sum(case when command like '%BACKUP%' then 1 else 0 end)
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_requests/row',1) 
		with (
			session_id int 
			,status nvarchar(30) 
			,wait_time int 
			,cpu_time int
			,waiting_tasks bigint ,
			command nvarchar(32)
		)
	group by case when session_id > 50 then 1 else 0 end
	option (maxdop 1, keep plan);

	--long requests
	select
		r.session_id,
		db.sqlwatch_database_id,
		cpu_time,
		reads,
		logical_reads,
		writes,
		r.spills,
		username,
		host_name,
		program_name = [dbo].[ufn_sqlwatch_parse_job_name] ( program_name, null, @sql_instance ),
		duration_ms,
		snapshot_time = @snapshot_time,
		snapshot_type_id = @snapshot_type_id,
		sql_instance = @sql_instance,
		sql_text,
		query_plan,
		request_id,
		start_time,
		command,
		query_hash = convert(varbinary(8),query_hash,1),
		query_plan_hash = convert(varbinary(8),query_plan_hash,1),
		start_time_utc = dateadd(minute,@timezoneoffset*-1,start_time),
		r.database_name,
		r.database_create_date,
		r.procedure_name
	into #t
	from openxml  (@xdoc, '/CollectionSnapshot/dm_exec_requests/row',1) 
	with (
		session_id int,
		cpu_time int,
		reads bigint,
		logical_reads bigint,
		writes bigint,
		spills int,
		duration_ms int,
		sql_text nvarchar(max),
		query_plan nvarchar(max),
		request_id int,
		database_name nvarchar(128),
		database_create_date datetime2(3),
		is_reportable bit,
		start_time datetime2(3),
		command nvarchar(32),
		query_hash varchar(255),
		query_plan_hash varchar(255),
		procedure_name nvarchar(512)
	) r
	inner join openxml (@xdoc, '/CollectionSnapshot/dm_exec_sessions/row',1)
	with (
		session_id int,
		username nvarchar(128),
		host_name nvarchar(128),
		program_name nvarchar(128)
	) s
	on s.session_id = r.session_id

	inner join dbo.sqlwatch_meta_database db
		on db.sql_instance = @sql_instance
		and db.database_name = r.database_name
		and db.database_create_date = r.database_create_date

	where r.is_reportable = 1
	and program_name not in (
		 'Microsoft SQL Server Management Studio' -- this is SSMS itself - listing objects etc, not user queries
		,'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense' 
		,'SQLServerCEIP' 
		,'SQLAgent - Job Manager' 
		,'SQLAgent - Job invocation engine' 
		,'SQLAgent - Schedule Saver'
	);

	insert into @sqlwatch_sql_query_plan (
		query_hash,
		query_plan_hash,
		query_plan,
		sql_text,
		database_name,
		database_create_date,
		procedure_name
	)
	select
		query_hash = convert(varbinary(8),query_hash,1),
		query_plan_hash = convert(varbinary(8),query_plan_hash,1),
		query_plan,
		sql_text,
		database_name,
		database_create_date,
		procedure_name
	from #t;

	exec [dbo].[usp_sqlwatch_internal_meta_add_sql_query]
		@sqlwatch_sql_query_plan = @sqlwatch_sql_query_plan,
		@sql_instance = @sql_instance;

	merge [dbo].[sqlwatch_logger_dm_exec_requests_long_requests] as target
	using (
		select tx.*
		from #t tx
		-- exclude queries containing text that we do not want to collect or coming from an excluded host or an application
		left join [dbo].[sqlwatch_config_exclude_logger_dm_exec_requests_long_requests] ex
			on case when ex.sql_text is not null then tx.sql_text else '%' end like isnull(ex.sql_text,'%')
			and case when ex.client_app_name is not null then tx.program_name else '%' end like isnull(ex.client_app_name,'%')
			and case when ex.client_hostname is not null then tx.host_name else '%' end like isnull(ex.client_hostname,'%')
			and case when ex.username is not null then tx.username else '%' end like isnull(ex.username,'%')

		where ex.[exclusion_id] is null
		
	) as source
	on source.session_id = target.session_id
	and source.request_id = target.request_id
	and source.start_time = target.start_time
	and source.sql_instance = target.sql_instance
	and source.snapshot_type_id = target.snapshot_type_id

	when matched then update
		set cpu_time = source.cpu_time,
			physical_reads = source.reads,
			logical_reads = source.logical_reads,
			writes = source.writes,
			spills = source.spills,
			duration_ms = source.duration_ms,
			snapshot_time = source.snapshot_time

	when not matched then 
		insert (
			[session_id],
			sqlwatch_database_id,
			[cpu_time] ,
			[physical_reads]  ,
			[logical_reads]  ,
			[writes],
			[spills],
			[username],
			[client_hostname],
			[client_app_name],
			[duration_ms] ,
			[snapshot_time],
			[snapshot_type_id],
			[sql_instance],
			--sql_text,
			--query_plan,
			request_id,
			start_time,
			command,
			query_hash,
			query_plan_hash,
			start_time_utc
		)
	values (
		source.[session_id],
		source.sqlwatch_database_id,
		source.[cpu_time] ,
		source.reads  ,
		source.[logical_reads]  ,
		source.[writes],
		source.[spills],
		source.[username],
		source.host_name,
		source.program_name,
		source.[duration_ms] ,
		source.[snapshot_time],
		source.[snapshot_type_id],
		source.[sql_instance],
		--case when source.query_hash is null then source.sql_text end,
		--case when source.query_plan_hash is null then source.query_plan end,
		source.request_id,
		source.start_time,
		source.command,
		source.query_hash,
		source.query_plan_hash,
		source.start_time_utc
	);

end;