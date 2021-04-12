CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_long_queries]
AS

set nocount on

declare @snapshot_type_id tinyint = 7,
		@snapshot_time datetime2(0),
		@target_data_char nvarchar(max),
		@target_data_xml xml,
		@utc_offset_minute int = [dbo].[ufn_sqlwatch_get_server_utc_offset]('MINUTE')

declare @execution_count bigint = 0,
		@session_name nvarchar(64) = 'SQLWATCH_long_queries',
		@address varbinary(8),
		@filename varchar(8000),
		@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

--quit of the collector is switched off
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

				--we shold build a safety check in here to make sure we dont blow the target table if there are many long queries.
				--something to check how many new long queries we get per second or minute and bail out if too many.
				--perhaps also disable XES if too many queries are being logged
			
				declare @event_data table (event_data xml)

				insert into @event_data
				select cast(event_data as xml)
				from sys.fn_xe_file_target_read_file ('SQLWATCH_long_queries*.xel', null, null, null) t

				set xact_abort on
				begin transaction

				exec [dbo].[usp_sqlwatch_internal_insert_header] 
					@snapshot_time_new = @snapshot_time OUTPUT,
					@snapshot_type_id = @snapshot_type_id

					SELECT 
						 attach_activity_id=left(xed.event_data.value('(action[@name="attach_activity_id"]/value )[1]', 'varchar(255)'),36) --discard sequence
						,[event_time]=xed.event_data.value('(@timestamp)[1]', 'datetime')
						,[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)')
						,[session_id]=isnull(xed.event_data.value('(action[@name="session_id"]/value)[1]', 'bigint'),0)
						,[database_name]=xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)')
						,[cpu_time]=xed.event_data.value('(data[@name="cpu_time"]/value)[1]', 'bigint')
						,[physical_reads]=xed.event_data.value('(data[@name="physical_reads"]/value)[1]', 'bigint')
						,[logical_reads]=xed.event_data.value('(data[@name="logical_reads"]/value)[1]', 'bigint')
						,[writes]=xed.event_data.value('(data[@name="writes"]/value)[1]', 'bigint')
						,[spills]=xed.event_data.value('(data[@name="spills"]/value)[1]', 'bigint')
						,[offset]=xed.event_data.value('(data[@name="offset"]/value)[1]', 'bigint')
						,[offset_end]=xed.event_data.value('(data[@name="offset_end"]/value)[1]', 'bigint')
						,[statement]=xed.event_data.value('(data[@name="statement"]/value)[1]', 'varchar(max)')
						,[username]=xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)')
						,[sql_text]=xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)')
						,[object_name]=nullif(xed.event_data.value('(data[@name="object_name"]/value)[1]', 'varchar(max)'),'')
						,[client_hostname]=xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)')
						,[client_app_name]=xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)')
						,[duration_ms]=xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint')/1000
						,[wait_type]=xed.event_data.value('(data[@name="wait_type"]/text )[1]', 'varchar(255)')
					into #t_queries
					from @event_data t
						cross apply t.event_data.nodes('event') as xed (event_data)
						where xed.event_data.value('(@name)[1]', 'varchar(255)') <> 'query_post_execution_showplan'

					select
						  attach_activity_id=left(xed.event_data.value('(action[@name="attach_activity_id"]/value )[1]', 'varchar(255)'),36)
					     ,query_plan = x.xml_fragment.query('.')

					into #t_plans
					from @event_data t
						cross apply t.event_data.nodes('event') as xed (event_data)
						cross apply t.event_data.nodes(N'/event/data[@name="showplan_xml"]/value/*') as x(xml_fragment)
						where xed.event_data.value('(@name)[1]', 'varchar(255)') = 'query_post_execution_showplan'

	
					insert into dbo.[sqlwatch_logger_xes_long_queries] (
						  [event_time], event_name, session_id, database_name
						, cpu_time, physical_reads, logical_reads, writes, spills
						, offset, offset_end, statement, username, sql_text
						, object_name, client_hostname, client_app_name
						, duration_ms, wait_type
						, snapshot_time, snapshot_type_id, sql_instance, [query_plan])

					select 
						  tx.[event_time], tx.event_name, tx.session_id, tx.database_name
						, tx.cpu_time, tx.physical_reads, tx.logical_reads, tx.writes, tx.spills
						, tx.offset, tx.offset_end, tx.statement, tx.username, tx.sql_text
						, tx.object_name, tx.client_hostname, tx.client_app_name
						, tx.duration_ms, tx.wait_type
						,[snapshot_time] = @snapshot_time
						,[snapshot_type_id] = @snapshot_type_id
						,sql_instance = @sql_instance
						,p.query_plan
					from #t_queries tx

					-- get saved plans
					left join #t_plans p
					on p.attach_activity_id = tx.attach_activity_id

					-- do not load queries that we arleady have
					left join dbo.[sqlwatch_logger_xes_long_queries] x
						on x.event_name = tx.event_name
						and x.event_time = tx.event_time
						and x.session_id = tx.session_id

					-- exclude queries containing text that we do not want to collect or coming from an excluded host or an application
					left join [dbo].[sqlwatch_config_exclude_xes_long_query] ex
						on case when ex.statement is not null then tx.statement else '%' end like isnull(ex.statement,'%')
						and case when ex.sql_text is not null then tx.sql_text else '%' end like isnull(ex.sql_text,'%')
						and case when ex.client_app_name is not null then tx.client_app_name else '%' end like isnull(ex.client_app_name,'%')
						and case when ex.client_hostname is not null then tx.client_hostname else '%' end like isnull(ex.client_hostname,'%')
						and case when ex.username is not null then tx.username else '%' end like isnull(ex.username,'%')

					--left join dbo.sqlwatch_config_exclude_wait_stats ew
					--	on ew.wait_type = tx.wait_type

					where ex.[exclusion_id] is null
					and x.event_time is null

				commit tran			
			
			
			end

	end
else
	print 'Product version must be 11 or higher'
