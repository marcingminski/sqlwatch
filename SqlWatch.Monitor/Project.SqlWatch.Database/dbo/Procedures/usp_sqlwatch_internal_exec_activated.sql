CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated]
as
begin
	set nocount on;

    declare @conversation_handle    uniqueidentifier,
            @message_type_name      nvarchar(128),
            @message_body           xml,
            @error_number           int,
            @error_message          nvarchar(max),
            @this_procedure_name    nvarchar(128),
            @sql                    nvarchar(max),
            @sql_params             nvarchar(max),
            @conversation_group_id  uniqueidentifier,
            @procedure_name         nvarchar(128),
            @timer                  smallint,
            @timestart              datetime2(7),
            @process_message        varchar(4000);

        begin try;

            set @this_procedure_name = OBJECT_NAME(@@PROCID);

            -- get items from our queue            
            receive top(1)
                  @conversation_handle = [conversation_handle]
                , @message_type_name = [message_type_name]
                , @message_body = cast([message_body] as xml)
		        , @conversation_group_id = conversation_group_id
                from dbo.sqlwatch_exec;
            
            -- if procedure is in the message body, it means we're running async execution rather than timer
            set @procedure_name = @message_body.value('(//procedure/name)[1]', 'nvarchar(128)');

            if @conversation_handle is not null
                begin

                    begin try

                        set @process_message = null;

                        if  @message_type_name = N'DEFAULT' and @procedure_name is not null
                            begin
                                set @timestart = SYSDATETIME();

                                exec @procedure_name;

                                set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + '; Procedure: ' + @procedure_name + '; Time Taken: ' + convert(varchar(100),datediff(ms,@timestart,SYSDATETIME())) + 'ms'
                            end

                        else if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
                            begin
                                
                                /* this could be a generic worker that we pass group id into and it works out what to run based on some meta data.
                                   for now however this will be hardcoded in batches 
                                   
                                   This code will execute procedures synchronously as sometimes dependencies are required.
                                   For example, we first want to collect database before we collect tables
                                        exec dbo.usp_sqlwatch_internal_add_database;
                                        exec dbo.usp_sqlwatch_internal_add_table;

                                   But we can also enqueue procedure to run asynchronously using:
                                   exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_logger_xes_blockers'

                                 */


                                -- 5 seconds batch
			                    if @conversation_group_id = 'B273076A-5D10-4527-909F-955707905890'
                                    begin                                        
                                        set @timer = 5
                                        begin conversation timer (@conversation_handle) timeout = @timer;
                                        
                                        set @timestart = SYSDATETIME();

                                        begin try

                                            exec dbo.usp_sqlwatch_logger_performance;
                                            exec dbo.[usp_sqlwatch_logger_requests_and_sessions];
                                        
                                        end try
                                        begin catch
                                            if @@TRANCOUNT > 0
                                                rollback transaction

                                            set @process_message = 'Activated procedure failed.'
                                            exec [dbo].[usp_sqlwatch_internal_log]
					                            @proc_id = @@PROCID,
					                            @process_stage = '130C078A-2AB2-4F07-AA5B-EA810388A553',
					                            @process_message = @process_message,
					                            @process_message_type = 'ERROR'

                                            Print @process_message + ' Please check application log for details.'
                                        end catch

                                        -- run async procedures now as they have their own error handler
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_logger_xes_blockers';

                                        set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + '; Timer: ' + convert(varchar(5),@timer) + '; Time Taken: ' + convert(varchar(100),datediff(ms,@timestart,SYSDATETIME()))  + 'ms'
                                    
                                    end

                                -- 1 minute batch
			                    if @conversation_group_id = 'A2719CB0-D529-46D6-8EFE-44B44676B54B'
                                    begin
                                        set @timer = 60;
                                        begin conversation timer (@conversation_handle) timeout = @timer;

                                        set @timestart = SYSDATETIME();

                                        -- execute async via broker:
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_process_checks';
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_logger_hadr_database_replica_states';

                                        begin try
                                            -- execute in sequence:
                                            exec dbo.usp_sqlwatch_logger_xes_waits
                                            exec dbo.usp_sqlwatch_logger_xes_diagnostics
                                            exec dbo.usp_sqlwatch_logger_xes_long_queries
                                            exec dbo.usp_sqlwatch_logger_xes_query_problems
                                        end try
                                        begin catch
                                            if @@TRANCOUNT > 0
                                                rollback transaction

                                            set @process_message = 'Activated procedure failed.'
                                            exec [dbo].[usp_sqlwatch_internal_log]
					                            @proc_id = @@PROCID,
					                            @process_stage = '34D2EFC9-5128-4117-AD11-2849828CFF6E',
					                            @process_message = @process_message,
					                            @process_message_type = 'ERROR'

                                            Print @process_message + ' Please check application log for details.'
                                        end catch

                                        set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + '; Timer: ' + convert(varchar(5),@timer) + '; Time Taken: ' + convert(varchar(100),datediff(ms,@timestart,SYSDATETIME()))  + 'ms'

                                    end

                                -- 10 minute batch
			                    if @conversation_group_id = 'F65F11A7-25CF-4A4D-8A4F-C75B03FE083F'
                                    begin
                                        set @timer = 600;
                                        begin conversation timer (@conversation_handle) timeout = @timer;

                                        set @timestart = SYSDATETIME();

                                        begin try
                                            exec dbo.usp_sqlwatch_logger_agent_job_history
                                            exec dbo.usp_sqlwatch_logger_procedure_stats;
                                        end try
                                        begin catch
                                            if @@TRANCOUNT > 0
                                                rollback transaction

                                            set @process_message = 'Activated procedure failed.'
                                            exec [dbo].[usp_sqlwatch_internal_log]
					                            @proc_id = @@PROCID,
					                            @process_stage = '0C1A3576-0B40-4871-8D4E-7490F5B91910',
					                            @process_message = @process_message,
					                            @process_message_type = 'ERROR'

                                            Print @process_message + ' Please check application log for details.'
                                        end catch

                                        set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + '; Timer: ' + convert(varchar(5),@timer) + '; Time Taken: ' + convert(varchar(100),datediff(ms,@timestart,SYSDATETIME()))  + 'ms'

                                    end

                                -- 1 hour batch
			                    if @conversation_group_id = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A'
                                    begin
                                        set @timer = 3600;
                                        begin conversation timer (@conversation_handle) timeout = @timer;

                                        set @timestart = SYSDATETIME();

                                        begin try

                                            --execute in sequence:
                                            exec dbo.usp_sqlwatch_internal_add_database;
                                            exec dbo.usp_sqlwatch_internal_add_master_file;
                                            exec dbo.usp_sqlwatch_internal_add_table;
                                            exec dbo.usp_sqlwatch_internal_add_job;
                                            exec dbo.usp_sqlwatch_internal_add_performance_counter;
                                            exec dbo.usp_sqlwatch_internal_add_memory_clerk;
                                            exec dbo.usp_sqlwatch_internal_add_wait_type;
                                            exec dbo.usp_sqlwatch_internal_add_index;

                                            --exec dbo.usp_sqlwatch_logger_disk_utilisation;

                                            --trends:
                                            exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 1, @valid_days = 7
                                            exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 5, @valid_days = 90
                                            exec dbo.usp_sqlwatch_trend_perf_os_performance_counters @interval_minutes = 60, @valid_days = 720;
                                        end try
                                        begin catch
                                            if @@TRANCOUNT > 0
                                                rollback transaction

                                            set @process_message = 'Activated procedure failed.'
                                            exec [dbo].[usp_sqlwatch_internal_log]
					                            @proc_id = @@PROCID,
					                            @process_stage = '441D488C-5872-4602-99E0-9C8080041DE9',
					                            @process_message = @process_message,
					                            @process_message_type = 'ERROR'

                                            Print @process_message + ' Please check application log for details.'
                                        end catch

                                        --execute async via broker:
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_retention';
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_purge_deleted_items';
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_expand_checks';
                                        exec [dbo].[usp_sqlwatch_internal_exec_activated_async] @procedure_name = 'dbo.usp_sqlwatch_internal_add_index_missing';

                                        set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + '; Timer: ' + convert(varchar(5),@timer) + '; Time Taken: ' + convert(varchar(100),datediff(ms,@timestart,SYSDATETIME()))  + 'ms'

                                    end     
                            end      
                    
				        if @process_message is not null
                            begin
                                exec [dbo].[usp_sqlwatch_internal_log]
					                @proc_id = @@PROCID,
					                @process_stage = '375C6590-D88D-4115-B8ED-2C0B6B6993D0',
					                @process_message = @process_message,
					                @process_message_type = 'INFO'
                            end

                    end try
                    begin catch
                        select  @error_number = ERROR_NUMBER(),
                                @error_message = ERROR_MESSAGE()
                            
                        if @@TRANCOUNT > 0
                            begin
                                rollback
                            end
                        end conversation @conversation_handle
                        raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @procedure_name, @error_number, @error_message);
                    end catch

                    if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
                        begin
                            -- we should get the error content from the broker here and output to the errorlog
                            select 
                                @error_message = @message_body.value ('(/Error/Description)[1]', 'nvarchar(4000)')
                            ,   @error_number = @message_body.value ('(/Error/Code)[1]', 'int')

                           --set @process_message = 'Message Type: ' + convert(varchar(4000),@message_type_name) + ';  (' + convert(varchar(100),@error_number) + ') ' + @error_message
                           --
                           --exec [dbo].[usp_sqlwatch_internal_log]
					       --    @proc_id = @@PROCID,
					       --    @process_stage = '17228F19-F167-48F2-AA3E-477516F64515',
					       --    @process_message = @process_message,
					       --    @process_message_type = 'ERROR'

                            print 'The converstaion ' + convert(varchar(max),@conversation_handle) + ' has returned an error (' + convert(varchar(10),@error_number) + ') ' + @error_message

                            end conversation @conversation_handle
                        end

                    if (
                            @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
                        or  @message_type_name = N'DEFAULT'
                        )
                        begin
                            end conversation @conversation_handle
                        end
                end
            else
                begin
                    if @@TRANCOUNT > 0
                        begin
                            rollback
                            end conversation @conversation_handle;
                        end
                    --raiserror(N'Variable @procedure_name in %s is null', 10, 10, @this_procedure_name);
                end
        end try
        begin catch
            select  @error_number = ERROR_NUMBER(),
                    @error_message = ERROR_MESSAGE()
                    
            if @@TRANCOUNT > 0
                begin
                    rollback;
                    end conversation @conversation_handle;
                end
            raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @this_procedure_name, @error_number, @error_message);
        end catch
end