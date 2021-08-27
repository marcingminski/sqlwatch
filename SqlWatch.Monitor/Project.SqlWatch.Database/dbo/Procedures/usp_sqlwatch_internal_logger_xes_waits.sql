CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_xes_waits]
	@data xml,
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin
	set nocount on;
	declare @execution_count bigint = 0,
			@session_name nvarchar(64) = 'SQLWATCH_waits',
			@address varbinary(8),
			@filename varchar(8000),
			@store_event_data smallint = dbo.ufn_sqlwatch_get_config_value(23,null),
			@last_event_time datetime,
			@sqlwatch_sql_query_plan as [dbo].[utype_sqlwatch_sql_query_plan]
			;

	--quit if the collector is switched off
	if (select collect 
		from [dbo].[sqlwatch_config_snapshot_type]
		where snapshot_type_id = @snapshot_type_id
		) = 0
		begin
			return;
		end;

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
			query_hash = isnull([dbo].[ufn_sqlwatch_convert_xes_hash](query_hash),[dbo].[ufn_sqlwatch_create_hash](sql_text)),
			query_plan_hash = [dbo].[ufn_sqlwatch_convert_xes_hash](query_plan_hash),
			query_plan = null,
			sql_text,
			database_name,
			database_create_date = null,
			procedure_name = 'Unknown'
		from openxml(@xdoc, '/CollectionSnapshot/XesData/row/event_data/event' ,1)
		with (
			query_hash decimal(20,0) 'action[@name="query_hash"]',
			query_plan_hash decimal(20,0) 'action[@name="query_plan_hash"]',
			sql_text nvarchar(max) 'action[@name="sql_text"]',
			[database_name] nvarchar(255) 'action[@name="database_name"]'
		);

		exec [dbo].[usp_sqlwatch_internal_meta_add_sql_query]
			@sqlwatch_sql_query_plan = @sqlwatch_sql_query_plan,
			@sql_instance = @sql_instance;

		insert into [dbo].[sqlwatch_logger_xes_wait_event] (
				event_time
				, wait_type_id
				, duration
				, signal_duration
				, session_id
				, username
				, client_hostname
				, client_app_name
				, sql_instance
				, snapshot_time
				, snapshot_type_id
				, activity_id
				, event_data
				, query_hash
				, query_plan_hash
				, sqlwatch_database_id
				, [database_create_date]
				, sqlwatch_procedure_id
				)
		select 
			w.event_time
			, s.wait_type_id
			, w.duration
			, w.signal_duration
			, w.session_id
			, username = isnull(w.username,w.nt_username)
			, w.client_hostname
			, client_app_name = [dbo].[ufn_sqlwatch_parse_job_name] ( w.client_app_name, j.job_name, @sql_instance )
			, sql_instance = @sql_instance
			, snapshot_time = @snapshot_time
			, snapshot_type_id = @snapshot_type_id
			, w.activity_id
			, event_data = @data.query('/CollectionSnapshot/XesData/row/event_data')
			, query_hash = isnull([dbo].[ufn_sqlwatch_convert_xes_hash](w.query_hash),[dbo].[ufn_sqlwatch_create_hash](w.sql_text))
			, query_plan_hash = [dbo].[ufn_sqlwatch_convert_xes_hash](w.query_plan_hash)
			, db.sqlwatch_database_id
			, db.[database_create_date]
			, mp.sqlwatch_procedure_id
		from openxml(@xdoc, '/CollectionSnapshot/XesData/row/event_data/event' ,1)
		with (
				[event_time] datetime2(3) '@timestamp',
				[wait_type] varchar(255) 'data[@name="wait_type"]/text',
				[duration] bigint  'data[@name="duration"]',
				[signal_duration] bigint  'data[@name="signal_duration"]',
				[activity_id] varchar(255) 'action[@name="attach_activity_id"]',
				[session_id] int 'action[@name="session_id"]',
				[username] nvarchar(255) 'action[@name="username"]',
				[nt_username] nvarchar(255) 'action[@name="session_nt_username"]',
				[client_hostname] nvarchar(255) 'action[@name="client_hostname"]',
				[client_app_name] nvarchar(255) 'action[@name="client_app_name"]',
				query_hash decimal(20,0) 'action[@name="query_hash"]',
				query_plan_hash decimal(20,0) 'action[@name="query_plan_hash"]',
				[database_name] nvarchar(255) 'action[@name="database_name"]',
				sql_text nvarchar(max) 'action[@name="sql_text"]'
		) w

		inner join dbo.[sqlwatch_meta_dm_os_wait_stats] s
			on s.wait_type = w.wait_type
			and s.sql_instance = @sql_instance

		inner join dbo.sqlwatch_meta_database db
			on db.sql_instance = @sql_instance
			and db.database_name = w.database_name
			and db.is_current = 1

		inner join [dbo].[sqlwatch_meta_procedure] mp
			on mp.sql_instance = @sql_instance
			and mp.sqlwatch_database_id = db.sqlwatch_database_id
			and mp.procedure_name = 'Unknown'
		
		left join dbo.sqlwatch_meta_agent_job j
			on j.job_id = [dbo].[ufn_sqlwatch_parse_job_id] ( client_app_name )
			and j.sql_instance = @sql_instance
			
		left join [dbo].[sqlwatch_logger_xes_wait_event] t
			on t.event_time = w.event_time
			and t.wait_type_id = s.wait_type_id
			and t.session_id = w.session_id
			and t.[sql_instance] = @sql_instance
			and t.[snapshot_time] = @snapshot_time
			and t.[snapshot_type_id] = @snapshot_type_id
			and t.activity_id = w.activity_id

		where t.event_time is null
		and w.wait_type not in (
				select wait_type from sqlwatch_config_exclude_wait_stats
			);

end;

