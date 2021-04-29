CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_waits]
AS


set nocount on

declare @snapshot_time datetime2(0),
		@snapshot_type_id tinyint = 6

declare @execution_count bigint = 0,
		@session_name nvarchar(64) = 'SQLWATCH_waits',
		@address varbinary(8),
		@filename varchar(8000),
		@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername(),
		@store_event_data smallint = dbo.ufn_sqlwatch_get_config_value(23,null),
		@last_event_time datetime;;

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

				declare @event_data utype_event_data;

				select @last_event_time = max(event_time) from dbo.[sqlwatch_logger_xes_long_queries];

				insert into @event_data
				exec [dbo].[usp_sqlwatch_internal_get_xes_data]
					@session_name = @session_name,
					@last_event_time = @last_event_time;

				select
					[event_time] = xed.event_data.value('(@timestamp)[1]', 'datetime'),
					[wait_type] = xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)'),
					[duration] = xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint'),
					[signal_duration] = xed.event_data.value('(data[@name="signal_duration"]/value)[1]', 'bigint'),
					[activity_id] = xed.event_data.value('(action[@name="attach_activity_id"]/value)[1]', 'varchar(255)'),
					--[query_hash] = xed.event_data.value('(action[@name="query_hash"]/value)[1]', 'decimal(20,0)'),
					[session_id] = xed.event_data.value('(action[@name="session_id"]/value)[1]', 'int'),
					[username] = isnull(xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)'),xed.event_data.value('(action[@name="session_nt_username"]/value)[1]', 'varchar(255)')),
					--[sql_text] = xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)'),
					[database_name] = xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)'),
					[client_hostname] = xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)'),
					[client_app_name] = xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)'),
					[plan_handle] = convert(varbinary(64),'0x' + xed.event_data.value('(action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1),
					offset_start = frame.event_data.value('(@offsetStart)[1]', 'varchar(255)'),
					offset_end = frame.event_data.value('(@offsetEnd)[1]', 'varchar(255)'),
					[sql_handle] = convert(varbinary(64),frame.event_data.value('(@handle)[1]', 'varchar(255)'),1),
					sql_instance = @sql_instance,
					event_data =  case when @store_event_data = 1 then event_data_xml else null end
				into #w
				from @event_data t
				cross apply t.event_data_xml.nodes('event') as xed (event_data)
				cross apply xed.event_data.nodes('//frame') as frame (event_data)
			
				-- exclude any waits we dont want to collect:
				where xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(255)') not in (
					select wait_type from sqlwatch_config_exclude_wait_stats
				)
				option (maxdop 1, keep plan);

				create nonclustered index idx_tmp_w on #w ( wait_type, sql_instance, event_time, session_id, activity_id );

				delete from #w
				where plan_handle = 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
				or offset_start is null
				or offset_end is null;

				--normalise query text and plans
				declare @plan_handle_table dbo.utype_plan_handle
				insert into @plan_handle_table (plan_handle, statement_start_offset, statement_end_offset, [sql_handle] )
				select distinct plan_handle,  offset_start, offset_end, [sql_handle]
				from #w
				;

				begin transaction plans;

				declare @sqlwatch_plan_id dbo.utype_plan_id
				insert into @sqlwatch_plan_id 
				exec [dbo].[usp_sqlwatch_internal_get_query_plans]
					@plan_handle = @plan_handle_table, 
					@sql_instance = @sql_instance
				;

				exec [dbo].[usp_sqlwatch_internal_insert_header] 
					@snapshot_time_new = @snapshot_time OUTPUT,
					@snapshot_type_id = @snapshot_type_id
				;

				commit transaction plans; --persist plans

				begin transaction dataload;

				begin try

					insert into [dbo].[sqlwatch_logger_xes_wait_event] (
							  event_time
							, wait_type_id
							, duration
							, signal_duration
							, session_id
							, username
							, client_hostname
							, client_app_name
							, plan_handle
							, statement_start_offset
							, statement_end_offset
							, sql_instance
							, snapshot_time
							, snapshot_type_id
							, activity_id
							, event_data
							)
					select 
							w.event_time
						, s.wait_type_id
						, w.duration
						, w.signal_duration
						, w.session_id
						, w.username
						, w.client_hostname
						, client_app_name = [dbo].[ufn_sqlwatch_parse_job_name] ( w.client_app_name, j.name )
						, w.plan_handle
						, w.offset_start
						, w.offset_end
						, w.sql_instance
						, snapshot_time = @snapshot_time
						, snapshot_type_id = @snapshot_type_id
						, w.activity_id
						, w.event_data
					from #w w
			
					inner join dbo.sqlwatch_meta_wait_stats s
						on s.wait_type = w.wait_type
						and s.sql_instance = w.sql_instance
		
					left join msdb.dbo.sysjobs j
						on j.job_id = [dbo].[ufn_sqlwatch_parse_job_id] (client_app_name )
			
					left join [dbo].[sqlwatch_logger_xes_wait_event] t
						on t.event_time = w.event_time
						and t.session_id = w.session_id
						and t.sql_instance = w.sql_instance
						and s.wait_type = w.wait_type
						and w.activity_id = t.activity_id

					where t.event_time is null;

					commit transaction dataload;

					--update execution count
					exec [dbo].[usp_sqlwatch_internal_update_xes_query_count] 
							@session_name = @session_name
						, @execution_count = @execution_count;

				end try
				begin catch
					if @@TRANCOUNT > 0
						rollback transaction dataload;

						exec [dbo].[usp_sqlwatch_internal_log]
							@proc_id = @@PROCID,
							@process_stage = 'D3D0A427-8CD8-4CBC-BB35-FE872A728704',
							@process_message = null,
							@process_message_type = 'ERROR';
				end catch
		end
	end
else
	begin
		exec [dbo].[usp_sqlwatch_internal_log]
			@proc_id = @@PROCID,
			@process_stage = '1535C6B0-F2BE-4745-8097-3D5F99A28701',
			@process_message = 'Product version must be 11 or higher to use Extended Events',
			@process_message_type = 'WARNING';
	end

