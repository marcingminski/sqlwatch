CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_create_xes]
	@session_name nvarchar(64) = null,
	@show_sql bit = 0
AS

declare @sql varchar(max) = '';


	if @session_name = 'SQLWATCH_long_queries' or @session_name  is null
		begin
			if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
				begin
					set @sql+= N'
						if exists (select 1 from sys.server_event_sessions where name = ''SQLWATCH_long_queries'')
							begin
								DROP EVENT SESSION [SQLWATCH_long_queries] ON SERVER;
							end;
					';
				end
		end

	if @session_name = 'SQLWATCH_blockers' or @session_name  is null
		begin
			if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
				begin
					set @sql+= N'
						if exists (select 1 from sys.server_event_sessions where name = ''SQLWATCH_blockers'')
							begin
								DROP EVENT SESSION [SQLWATCH_blockers] ON SERVER;
							end;

						CREATE EVENT SESSION [SQLWATCH_blockers]
						ON SERVER 

						/*  a custom session to capture blockers as the default health_session is quite busy and would sometimes drop messages
							and generates relatively large xml that can take few seconds to parse. 
	
							Remove when targeting SQL2008	*/
						ADD EVENT sqlserver.blocked_process_report(
							ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.tsql_stack,sqlserver.username)),
						ADD EVENT sqlserver.xml_deadlock_report
						ADD TARGET package0.event_file(SET filename=''SQLWATCH_blockers.xel'', max_file_size=(5), max_rollover_files=(0))
						--ADD TARGET package0.ring_buffer(SET max_events_limit=(100))
						WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
						;
						
						ALTER EVENT SESSION [SQLWATCH_blockers] ON SERVER STATE = START;
					';
				end;
		end;

	if @session_name = 'SQLWATCH_waits' or @session_name  is null
		begin
			if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
				begin
					set @sql+= N'
						if exists (select 1 from sys.server_event_sessions where name = ''SQLWATCH_waits'')
							begin
								DROP EVENT SESSION [SQLWATCH_waits] ON SERVER;
							end;

							CREATE EVENT SESSION [SQLWATCH_waits]
							ON SERVER

							/*	any query that waited over 1 second for a resource
								If a query has to wait over 1 second for a resource you have a big performnace problem.
								Remove when targeting SQL2008	*/

							--2014 onwards:
							--ADD EVENT sqlos.wait_completed(SET collect_wait_resource=(1)
							--    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.query_hash,sqlserver.query_hash_signed,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text,sqlserver.username)
							--    WHERE ([package0].[greater_than_uint64]([duration],(1000)) AND [sqlserver].[not_equal_i_sql_unicode_string]([sqlserver].[sql_text],N'''')))

							ADD EVENT sqlos.wait_info(
								ACTION(sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.sql_text, sqlserver.tsql_frame,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.username)
								WHERE (
										--the filter criteria will be the same for all events in this session:

										--only waits lasting over 1 second 
										[package0].[greater_than_uint64]([duration],(1000)) 

										--only waits that are in a database, this would exclude any background waits that we cannot do anything about
									AND [package0].[greater_than_uint64]([sqlserver].[database_id],(0)) 

										--only include user waits and exclude any system processes
									AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))

									/* exclude anything coming from SSMS that isn''t a user query. Queries will be Microsoft SQL Server Management Studio - Query */
									AND [sqlserver].[client_app_name]<>N''Microsoft SQL Server Management Studio''
									/* if intellinse causes blocking, which it may do, we''re gonna pick it up in the blocking session 
									   otherwise, whilst its a bad practice to run ssms in production, there''s not much we can do about intellisense */
									AND [sqlserver].[client_app_name]<>N''Microsoft SQL Server Management Studio - Transact-SQL IntelliSense''
        
									/* exclude internal sql agent job management, NOT user jobs. User jobs come across as: 
									   SQLAgent - TSQL JobStep (Job 0x123456789123456798 : Step 3) */
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Job Manager''
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Job invocation engine''
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Schedule Saver''
									),

							ADD EVENT sqlos.wait_info_external(
								ACTION(sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.sql_text, sqlserver.tsql_frame, sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.username)
								WHERE (
										[package0].[greater_than_uint64]([duration],(1000)) 
									AND [package0].[greater_than_uint64]([sqlserver].[database_id],(0)) 
									AND [package0].[equal_boolean]([sqlserver].[is_system],(0)))
									AND [sqlserver].[client_app_name]<>N''Microsoft SQL Server Management Studio''
									AND [sqlserver].[client_app_name]<>N''Microsoft SQL Server Management Studio - Transact-SQL IntelliSense''
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Job Manager''
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Job invocation engine''
									AND [sqlserver].[client_app_name]<>N''SQLAgent - Schedule Saver''
									)

							ADD TARGET package0.event_file(SET filename=''SQLWATCH_waits.xel'',max_file_size=(2),max_rollover_files=(1))
							WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=1 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON);

							ALTER EVENT SESSION [SQLWATCH_waits] ON SERVER STATE = START;
					'
				end
		end;

if @show_sql = 1
	begin
		select sql = @sql, len=len(@sql);
	end
else
	begin
		exec (@sql);
	end;