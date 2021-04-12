CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_requests_and_sessions]
as

	declare @snapshot_type_id tinyint = 30,
			@snapshot_time datetime2(0),
			@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id;

	insert into dbo.sqlwatch_logger_dm_exec_requests_stats (
		[type]
		, background
		, running
		, runnable
		, sleeping
		, suspended
		, waiting_tasks
		, wait_duration_ms
		, snapshot_time
		, snapshot_type_id
		, sql_instance
	)
	select 
		  'type' = case when r.session_id > 50 then 1 else 0 end
		, 'background' = sum(case status when 'Background' then 1 else 0 end)
		-- exclude our own session from counting. This way, if there are no other sessions we can still get a count that shows 0
		-- if we excluded it in the where clause, we would have had a missing for this snapshot time which would have upset dashboards
		, 'running' = sum(case when status = 'Running' and session_id <> @@SPID then 1 else 0 end)
		, 'runnable' = sum(case status when 'Runnable' then 1 else 0 end)
		, 'sleeping' = sum(case status when 'Sleeping' then 1 else 0 end)
		, 'suspended' = sum(case status when 'Suspended' then 1 else 0 end)
		, 'waiting_tasks' = sum(sessions)
		, 'wait_duration_ms' = isnull(sum(tc.wait_duration_ms),0)
		, snapshot_time = @snapshot_time
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance
	from sys.dm_exec_requests r (nolock)
	cross apply (
		select wait_duration_ms=sum(wait_duration_ms), sessions=count(session_id)
		from sys.dm_os_waiting_tasks t (nolock)
		where t.session_id = r.session_id
		and wait_type collate database_default not in (
			select wait_type 
			from dbo.sqlwatch_config_exclude_wait_stats (nolock)
			) 
		) tc
	group by case when r.session_id > 50 then 1 else 0 end
	option (keep plan);

	insert into dbo.sqlwatch_logger_dm_exec_sessions_stats (
		  [type]
		, running
		, sleeping
		, dormant
		, preconnect
		, cpu_time
		, reads
		, writes
		, snapshot_time
		, snapshot_type_id
		, sql_instance
	)
	select 
		'type' = is_user_process
		-- exclude our own session from counting. This way, if there are no other sessions we can still get a count that shows 0
		-- if we excluded it in the where clause, we would have had a missing for this snapshot time which would have upset dashboards
		,'running' = sum(case when status = 'Running' and session_id <> @@SPID then 1 else 0 end)
		,'sleeping' = sum(case status when 'Sleeping' then 1 else 0 end)
		,'dormant' = sum(case status when 'Dormant' then 1 else 0 end)
		,'preconnect' = sum(case status when 'Preconnect' then 1 else 0 end)
		,'cpu_time' = avg(cpu_time)
		,'reads' = avg(reads)
		,'writes' = avg(writes)
		, snapshot_time = @snapshot_time
		, snapshot_type_id = @snapshot_type_id
		, sql_instance = @sql_instance
	from sys.dm_exec_sessions (nolock)
	group by is_user_process
	option (keep plan)