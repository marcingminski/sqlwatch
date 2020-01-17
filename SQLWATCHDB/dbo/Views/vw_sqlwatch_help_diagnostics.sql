CREATE VIEW [dbo].[vw_sqlwatch_help_diagnostics]
as

select sqlwatch_diagnostics = (
	select 
		 sql_version = @@VERSION
		,timegerenated = convert(varchar(100),SYSDATETIMEOFFSET(),121)
		,sqlwatch_version = (
			select top 1 install_sequence, install_date =convert(varchar(100),install_date,121), sqlwatch_version
			from [dbo].[sqlwatch_app_version] 
			order by install_sequence desc
			for xml raw, type)
		,last_snapshot = (
			select 
				  [sql_instance_anonym] = master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
				, [snapshot_type_id]
				, [snapshot_type_desc]
				, [snapshot_time_utc]
				, [snapshot_time_local]
				, [snapshot_age_minutes]
				, [snapshot_age_hours] 
			from [dbo].[vw_sqlwatch_help_last_snapshot_time]
			for xml raw, type
			)
		,default_checks = (
			select 
				  [sql_instance_anonym] = master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
				, [check_id]
				, [check_name]
				, [last_check_date]
				, [last_check_value]
				, [last_check_status]
				, [last_status_change_date]
				, [avg_check_exec_time_ms]
				, [total_checks_executed] 
				from [dbo].[vw_sqlwatch_report_dim_check]
			where check_id < 0
			for xml raw, type
		)

		,sql_watch_jobs = (
			select 
				  sj.name
				, step_name
				, last_run_outcome = case last_run_outcome
					when 0 then 'Failed'
					when 1 then 'Succeeded'
					when 2 then 'Retry'
					when 3 then 'Canceled'
					when 5 then 'Unknown'
				end
				, last_run_duration
				, [last_run_datetime] = case when last_run_date > 0 and last_run_time > 0 then msdb.dbo.agent_datetime(last_run_date,last_run_time) else null end
			from msdb.dbo.sysjobsteps sjs
				inner join msdb.dbo.sysjobs sj
				on sjs.job_id = sj.job_id
			where command like '%sqlwatch%'
			for xml raw, type
		)

		, sqlwatch_table_size = (
			select 
				table_name = t.NAME,
				row_count = p.rows,
				total_space_MB = CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)),
				used_space_MB = CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)), 
				unused_space_MB = CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)),
				p.[data_compression_desc]
			from sys.tables t
			inner join sys.indexes i ON t.OBJECT_ID = i.object_id
			inner join sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
			inner join sys.allocation_units a ON p.partition_id = a.container_id
			left join sys.schemas s ON t.schema_id = s.schema_id
			where 
				t.NAME NOT LIKE 'dt%' 
				AND t.is_ms_shipped = 0
				AND i.OBJECT_ID > 255 
				and t.name like '%sqlwatch%'
			group by t.Name, s.Name, p.Rows, p.[data_compression_desc]
			order by t.Name
			for xml raw, type
		)

		, logger_log_error_stats = (
			select sql_instance_anonym = master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
			, process_name, ERROR_COUNT=count(*)
			from [dbo].[sqlwatch_app_log]
			where event_time > dateadd(hour,-24,getutcdate())
			and [process_message_type] = 'ERROR'
			group by master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
			, process_name
			for xml raw, type
		)

		, logger_log_errors = (
			select event_sequence, event_time, sql_instance_anonym = master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
			, process_name, process_stage, [ERROR_NUMBER],[ERROR_SEVERITY],[ERROR_STATE],[ERROR_PROCEDURE],[ERROR_LINE],[ERROR_MESSAGE]
			from [dbo].[sqlwatch_app_log]
			where [event_time] > dateadd(hour,-24,getutcdate())
			and [process_message_type] = 'ERROR'
			for xml raw, type
		)

		, central_repo_import_status = (
			select sql_instance_anonym = master.dbo.fn_varbintohexstr(HashBytes('MD5', [sql_instance]))
				  ,[object_name]
				  ,[import_status]
				  ,[import_end_time]
				  ,[exec_proc]
			  from [dbo].[sqlwatch_meta_repository_import_status]
			  for xml raw, type
		)

		, enabled_actions = (
			select action_id 
			from [dbo].[sqlwatch_config_action]
			where action_enabled = 1
			for xml raw, type
	)

		, check_action = (
			SELECT cca.[check_id], cca.[action_id], cca.[action_every_failure], cca.[action_recovery], cca.[action_repeat_period_minutes]
			, cca.[action_hourly_limit], cca.[action_template_id], cca.[date_created], cca.[date_updated]
			, ca.action_enabled, ca.action_exec_type
			FROM [dbo].[sqlwatch_config_check_action] cca
				left join [dbo].[sqlwatch_config_action] ca
				on ca.action_id = cca.action_id
			for xml raw, type
		)

		, action_queue_stats = (
			SELECT [exec_status], count=count(*)
			  FROM [dbo].[sqlwatch_meta_action_queue]
			group by [exec_status]
			for xml raw, type
		)
	for xml path('diagnostics'), type
)