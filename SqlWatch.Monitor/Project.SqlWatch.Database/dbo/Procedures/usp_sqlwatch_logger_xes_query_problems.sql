CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_query_problems]
as


set nocount on

declare @snapshot_type_id tinyint = 31,
		@snapshot_time datetime2(0),
		@target_data_char nvarchar(max),
		@target_data_xml xml

declare @execution_count bigint = 0,
		@session_name nvarchar(64) = 'SQLWATCH_query_problems',
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

				set xact_abort on
				begin transaction

				--update execution count
				exec [dbo].[usp_sqlwatch_internal_update_xes_query_count] 
					  @session_name = @session_name
					, @execution_count = @execution_count

				--we shold build a safety check in here to make sure we dont blow the target table if there are many long queries.
				--something to check how many new long queries we get per second or minute and bail out if too many.
				--perhaps also disable XES if too many queries are being logged
			
				declare @event_data table (
					  event_data xml
					, [event_hashbytes] varbinary(20) 
					, occurence int 
					unique ([event_hashbytes], occurence)
					)

				--SQL Server logs is multiple occurences of the plan_affecting_convert event with the exact same data.
				--I am not sure whethere this is a bug in SQL Server or my XES is somehow incorrect. I will look into this in the future or raise a bug with MS
				insert into @event_data
				select cast(event_data as xml)
					, [event_hashbytes]=hashbytes('SHA1',event_data)
					, occurence = ROW_NUMBER() over (partition by hashbytes('SHA1',event_data) order by (select null))
				from sys.fn_xe_file_target_read_file ('SQLWATCH_query_problems*.xel', null, null, null) t
				option (maxdop 1, keepfixed plan)

				exec [dbo].[usp_sqlwatch_internal_insert_header] 
					@snapshot_time_new = @snapshot_time OUTPUT,
					@snapshot_type_id = @snapshot_type_id

					SELECT 
						 [event_time]=xed.event_data.value('(@timestamp)[1]', 'datetime')
						,[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)')
						,[username]=xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)')
						--,[sql_text]=xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)')
						,[client_hostname]=xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)')
						,[client_app_name]=xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)')
						,[problem_details] = t.event_data
						,[event_hashbytes]
						,occurence
					into #t_queries
					from @event_data t
						cross apply t.event_data.nodes('event') as xed (event_data)
						where xed.event_data.value('(@name)[1]', 'varchar(255)') <> 'query_post_execution_showplan'
	
					insert into dbo.[sqlwatch_logger_xes_query_problems] (
						  [event_time], event_name, username
						, client_hostname, client_app_name
						, snapshot_time, snapshot_type_id, sql_instance, [problem_details], [event_hashbytes], occurence)

					select 
						  tx.[event_time], tx.event_name, tx.username
						, tx.client_hostname, tx.client_app_name
						,[snapshot_time] = @snapshot_time
						,[snapshot_type_id] = @snapshot_type_id
						,sql_instance = @sql_instance
						,tx.[problem_details]
						,tx.[event_hashbytes]
						,occurence = o.occurence
					from #t_queries tx

					-- do not load queries that we arleady have
					left join dbo.[sqlwatch_logger_xes_query_problems] x
						on x.[event_hashbytes] = tx.[event_hashbytes]
						and x.event_time = tx.event_time
						and x.event_name = tx.event_name

					outer apply (
						select occurence=max(occurence)
						from #t_queries
						where [event_hashbytes] = tx.[event_hashbytes]
					) o

					where tx.occurence = 1 
					and x.[event_hashbytes] is null

				commit tran					
			end
	end
else
	print 'Product version must be 11 or higher'
