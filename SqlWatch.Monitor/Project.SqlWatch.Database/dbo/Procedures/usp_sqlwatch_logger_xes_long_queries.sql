CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_long_queries]
AS

set nocount on;

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
				--we shold build a safety check in here to make sure we dont blow the target table if there are many long queries.
				--something to check how many new long queries we get per second or minute and bail out if too many.
				--perhaps also disable XES if too many queries are being logged
				select event_data=convert(xml,event_data), object_name
				into #event_data
				from sys.fn_xe_file_target_read_file ('SQLWATCH_long_queries*.xel', null, null, null) t

				-- get only new events. This results in much smaller xml to parse in the steps below and dramatically speeds up the query
				where [dbo].[ufn_sqlwatch_get_xes_timestamp]( event_data ) >=
				isnull((select max(event_time) from dbo.[sqlwatch_logger_xes_long_queries]),'1970-01-01')

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
						,[offset_start]=xed.event_data.value('(data[@name="offset"]/value)[1]', 'bigint')
						,[offset_end]=xed.event_data.value('(data[@name="offset_end"]/value)[1]', 'bigint')
						,[username]=xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)')
						--,[object_name]=nullif(xed.event_data.value('(data[@name="object_name"]/value)[1]', 'varchar(max)'),'')
						,[client_hostname]=xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)')
						,[client_app_name]=xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)')
						,[duration_ms]=xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint')/1000
						,[wait_type]=xed.event_data.value('(data[@name="wait_type"]/text )[1]', 'varchar(255)')
						,[plan_handle] = convert(varbinary(64),'0x' + xed.event_data.value('(action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1)

						--for best performance, sql text exclusions could be baked into the xes so we do not even collect anything we do not want
						--this would require dynamic xes creation which is something I will look to do in the future
						,[sql_text] = xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)')
						,sql_instance = @sql_instance
					into #t_queries
					from #event_data t
						cross apply t.event_data.nodes('event') as xed (event_data);

					create nonclustered index idx_tmp_t_queries_1 on #t_queries (sql_instance, plan_handle, [offset_start], [offset_end]);
					create nonclustered index idx_tmp_t_queries_2 on #t_queries (event_name, event_time, session_id, sql_instance);
					
					--normalise query text and plans
					declare @plan_handle_table utype_plan_handle
					insert into @plan_handle_table (plan_handle, statement_start_offset, statement_end_offset )
					select distinct plan_handle,  offset_start, offset_end
					from #t_queries

					begin transaction;

					declare @sqlwatch_plan_id dbo.utype_plan_id
					insert into @sqlwatch_plan_id 
					exec [dbo].[usp_sqlwatch_internal_get_query_plans]
						@plan_handle = @plan_handle_table, 
						@sql_instance = @sql_instance
					;
					
					commit transaction;

					begin transaction dataload;

					begin try
						insert into dbo.[sqlwatch_logger_xes_long_queries] (
							  [event_time], event_name, session_id, sqlwatch_database_id
							, cpu_time, physical_reads, logical_reads, writes, spills
							, username
							, client_hostname, client_app_name
							, duration_ms
							, snapshot_time, snapshot_type_id 
							, sqlwatch_query_plan_id
							, attach_activity_id
							, sql_instance
							)

						select distinct --as we may have multiple plan handles for each query here
							  tx.[event_time], tx.event_name, tx.session_id, db.sqlwatch_database_id
							, tx.cpu_time, tx.physical_reads, tx.logical_reads, tx.writes, tx.spills
							, tx.username
							, tx.client_hostname
							, client_app_name = [dbo].[ufn_sqlwatch_parse_job_name] ( tx.client_app_name, j.name )
							, tx.duration_ms
							, [snapshot_time] = @snapshot_time
							, [snapshot_type_id] = @snapshot_type_id
							, qp.sqlwatch_query_plan_id
							, tx.attach_activity_id
							, tx.sql_instance
						from #t_queries tx

						inner join dbo.sqlwatch_meta_database db
							on db.database_name = tx.database_name
							and db.is_current = 1

						inner join [dbo].[sqlwatch_meta_query_plan_handle] qph
							on qph.plan_handle = tx.plan_handle
							and qph.statement_start_offset = tx.offset_start
							and qph.statement_end_offset = tx.offset_end
							and qph.sql_instance = tx.sql_instance
			
						inner join [dbo].[sqlwatch_meta_query_plan] qp
							on qp.query_hash = qph.query_hash
							and qp.query_plan_hash = qph.query_plan_hash
							and qp.sql_instance = qph.sql_instance

						-- do not load queries that we arleady have
						left join dbo.[sqlwatch_logger_xes_long_queries] x
							on x.event_name = tx.event_name
							and x.event_time = tx.event_time
							and x.session_id = tx.session_id
							and x.sql_instance = tx.sql_instance

						left join msdb.dbo.sysjobs j
							on j.job_id = [dbo].[ufn_sqlwatch_parse_job_id] ( tx.client_app_name )

						-- exclude queries containing text that we do not want to collect or coming from an excluded host or an application
						left join [dbo].[sqlwatch_config_exclude_xes_long_query] ex
							on case when ex.sql_text is not null then tx.sql_text else '%' end like isnull(ex.sql_text,'%')
							and case when ex.client_app_name is not null then tx.client_app_name else '%' end like isnull(ex.client_app_name,'%')
							and case when ex.client_hostname is not null then tx.client_hostname else '%' end like isnull(ex.client_hostname,'%')
							and case when ex.username is not null then tx.username else '%' end like isnull(ex.username,'%')

						where ex.[exclusion_id] is null
						and x.event_time is null

						if @@TRANCOUNT > 0
							commit transaction dataload;

					end try
					begin catch
						select * from #t_queries
						select ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE()

						if @@TRANCOUNT > 0
							begin
								rollback tran dataload
							end
					end catch

				--update execution count
				exec [dbo].[usp_sqlwatch_internal_update_xes_query_count] 
					  @session_name = @session_name
					, @execution_count = @execution_count
			
			end

	end
else
	print 'Product version must be 11 or higher'
