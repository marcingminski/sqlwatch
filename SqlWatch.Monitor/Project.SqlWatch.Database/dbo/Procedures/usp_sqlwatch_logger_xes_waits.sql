CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_waits]
AS


set nocount on

declare @event_data table (event_data xml)
declare @snapshot_time datetime2(0),
		@snapshot_type_id tinyint = 6

declare @execution_count bigint = 0,
		@session_name nvarchar(64) = 'SQLWATCH_waits',
		@address varbinary(8),
		@filename varchar(8000),
		@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

if (select collect from [dbo].[sqlwatch_config_snapshot_type]
	where snapshot_type_id = @snapshot_type_id) = 0
		begin
			return
		end

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin

		set @execution_count = [dbo].[ufn_sqlwatch_get_xes_exec_count] ( @session_name, 0 )
		if  @execution_count > [dbo].[ufn_sqlwatch_get_xes_exec_count] ( @session_name, 1 )
			begin
				--update execution count
				exec [dbo].[usp_sqlwatch_internal_update_xes_query_count] 
					  @session_name = @session_name
					, @execution_count = @execution_count


			select event_data_xml=convert(xml,event_data), object_name
			into #event_data
			from sys.fn_xe_file_target_read_file ('SQLWATCH_waits*.xel', null, null, null) t

			-- get only new events. This results in much smaller xml to parse in the steps below and dramatically speeds up the query
			where substring(event_data,PATINDEX('%timestamp%',event_data)+len('timestamp="'),24) >=
			isnull((select max(event_time) from [dbo].[sqlwatch_logger_xes_wait_event]),'1970-01-01')

			select
				[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
				[wait_type] = xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)'),
				[duration] = xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint'),
				[signal_duration] = xed.event_data.value('(data[@name="signal_duration"]/value)[1]', 'bigint'),
				[activity_id] = xed.event_data.value('(action[@name="attach_activity_id"]/value)[1]', 'varchar(255)'),
				[query_hash] = xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'),
				[session_id] = xed.event_data.value('(action[@name="session_id"]/value)[1]', 'int'),
				[username] = isnull(xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)'),xed.event_data.value('(action[@name="session_nt_username"]/value)[1]', 'varchar(255)')),
				[sql_text] = xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)'),
				[database_name] = xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)'),
				[client_hostname] = xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)'),
				[client_app_name] = xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)'),
				[plan_handle] = convert(varbinary(64),'0x' + xed.event_data.value('(action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1),
				sql_instance = dbo.ufn_sqlwatch_get_servername()
			into #w
			from #event_data t
			cross apply t.event_data_xml.nodes('event') as xed (event_data)
			
			-- exclude any waits we dont want to collect:
			where xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)') not in (
				select wait_type from sqlwatch_config_exclude_wait_stats
			)


			--normalise query text and plans
			declare @plan_handle_table utype_plan_handle
			insert into @plan_handle_table
			select distinct plan_handle 
			from #w

			exec [dbo].[usp_sqlwatch_internal_normalise_query_text]
				@plan_handle = @plan_handle_table, 
				@sql_instance = @sql_instance
			;

			exec [dbo].[usp_sqlwatch_internal_normalise_plan_handle]
				@plan_handle = @plan_handle_table, 
				@sql_instance = @sql_instance
			;

			exec [dbo].[usp_sqlwatch_internal_insert_header] 
				@snapshot_time_new = @snapshot_time OUTPUT,
				@snapshot_type_id = @snapshot_type_id

			insert into [dbo].[sqlwatch_logger_xes_wait_event] (
					event_time
				, wait_type_id
				, duration
				, signal_duration
				, session_id
				--, activity_id
				--, activity_id_sequence
				, username
				, sqlwatch_database_id
				, client_hostname
				, client_app_name
				, query_hash
				, sqlwatch_query_plan_id
				, sqlwatch_query_id
				, sql_instance
				, snapshot_time
				, snapshot_type_id
				)
			select 
					w.event_time
				, s.wait_type_id
				, w.duration
				, w.signal_duration
				, w.session_id
				--, w.activity_id
				--, w.activity_id_sequence
				, w.username
				, db.sqlwatch_database_id
				, w.client_hostname
				, client_app_name = case when w.client_app_name like 'SQLAGent - TSQL JobStep%' then replace(w.client_app_name collate DATABASE_DEFAULT,left(replace(w.client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),j.name) else w.client_app_name end
				, w.query_hash
				, qp.sqlwatch_query_plan_id
				, qp.sqlwatch_query_id
				, w.sql_instance
				, @snapshot_time
				, @snapshot_type_id
			from #w w
			
			inner join dbo.sqlwatch_meta_wait_stats s
				on s.wait_type = w.wait_type
				and s.sql_instance = w.sql_instance
			
			inner join dbo.sqlwatch_meta_database db
				on db.database_name = w.database_name
				and db.is_current = 1
				and db.sql_instance = w.sql_instance

			inner join dbo.sqlwatch_meta_query_plan qp
				on qp.plan_handle = w.plan_handle
				and qp.sql_instance = w.sql_instance
			
			left join msdb.dbo.sysjobs j
				on j.job_id = convert(uniqueidentifier,case when client_app_name like 'SQLAGent - TSQL JobStep%' then convert(varbinary,left(replace(client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),1) else null end)
			
			left join [dbo].[sqlwatch_logger_xes_wait_event] t
				on t.event_time = w.event_time
				and t.session_id = w.session_id
				and t.sql_instance = w.sql_instance
				and s.wait_type = w.wait_type
			where t.event_time is null
		end


	end
else
	print 'Product version must be 11 or higher'

