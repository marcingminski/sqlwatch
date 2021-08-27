CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_activated_collector_queue]
as
begin
	set nocount on;
    set xact_abort on;

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
            @timerend               datetime2(7),
            @process_message        varchar(4000),
            @snapshot_type_id       tinyint,
            @snapshot_time          datetime2(0),
            @snapshot_time_new      datetime2(0),
            @sql_instance           varchar(32),
            @message_count          int = 1,
            @validation             char(1),
            @metadataname           nvarchar(50),
            @xdoc                   int,
            @snapshot_time_previous datetime2(0),
            @trancount              int,
            @conversation_group_id_txt varchar(255),
            @conversation_handle_txt varchar(255),
            @timezoneoffset         int
            ;

    set @this_procedure_name = OBJECT_NAME(@@PROCID);
    
    -- Using queues to process incoming data gives very high performance and flexibility. Queues are the backbone of high performance
    -- asyncronous processing. If the repository is busy and not able to write incoming data the queue will simply queue up more messages until they can be processed
    -- without the queue, we would either have to skip and lose some data or would just create a big chain and eventually kill the server, or have a big server.
    -- Queing up in the broker is only good for few minutes, maybe up to 1 hour depending on volumes. 
    -- Few minutes is enough to handle incoming data in case the repository is busy reading large amoung of data for the dashboard.
    -- There is a failsafe that will stop collection altogether if the queue grows too big to prevent blowing the log.
    -- If the queue grows really big then it means that the repository is not able to handle the data.
    
    begin try
        --while @message_count > 0
        while 1=1
            begin
                begin transaction;
	                waitfor (
                        receive top(1)
                              @conversation_handle = [conversation_handle]
                            , @message_type_name = [message_type_name]
                            , @message_body = cast([message_body] as xml)
		                    , @conversation_group_id = [conversation_group_id]
                            , @validation = [validation]
                            , @conversation_group_id_txt = convert(varchar(255),[conversation_group_id])
                            , @conversation_handle_txt = convert(varchar(255), [conversation_handle])
                        from dbo.sqlwatch_collector
                    ),
                    -- we're getting messages every 5 seconds so technically we should be waiting for at least 5 seconds.
                    -- however, this would create a scenario where the proc never ends and as its within a transaction, it would never release the log.
                    -- for that reason, we are going to wait 1 second only in case there are pending messages in the queue.
                    -- for any new messages a new instance of the proc will be created and the process repeated
                    -- 2021-08: actually, since we commit right away, I do not think the above still applies...
                    timeout 1000;

                if @@ROWCOUNT = 0
                    begin
                        --break loop if no messages to process
                        commit transaction;
                        break;
                    end;

                -- we are commiting the tran right after we have fetched the record from the queue.
                -- normally you would only commit transaction after the processing has finished.
                -- if the processing fails, the tran rolls back and the message goes back to the queue so no data is lost.
                -- however, troublesome payloads (say pk violations or deadlocks) would eventually trigger poison message and would disable the queue
                -- meaning no new data would be processesed unless the troublesome messages are cleared (often requiring manual intervention)
                -- for the purpose of reliablity over the quality, we are going to simply dismiss any troublesome messages and move on accepting some data loss - likely a single collection snapshot
                -- Also, note that when we hit an error, we dump the payload into the app_log table so the data is never actually lost just cleared from the queue.

                if @@TRANCOUNT > 0
                    begin
                        commit transaction;
                    end;

                if @conversation_handle is not null
                    begin
                          
                        if @message_type_name = N'mtype_sqlwatch_collector'
                            begin

                                if (@message_body.exist('/CollectionSnapshot')=0)
                                    begin
                                        if XACT_STATE() = 1
                                            begin
                                                commit transaction;
                                            end;
                                        break;
                                    end;

                                exec sp_xml_preparedocument @xdoc OUTPUT, @message_body;

                                select 
                                    @snapshot_time = snapshot_time,
                                    @snapshot_type_id = snapshot_type_id,
                                    @sql_instance = sql_instance,
                                    @timezoneoffset = timezoneoffset
                                from openxml (@xdoc, '/CollectionSnapshot/snapshot_header/row',1) 
                                with (
	                                snapshot_time datetime2(0),
	                                snapshot_type_id tinyint,
	                                sql_instance varchar(32),
                                    timezoneoffset int
                                )

                                if @snapshot_time is not null
                                    begin

                                        --process collection snapshots and load into tables:
                                        begin try

                                            --create header for the collection:
                                            exec [dbo].[usp_sqlwatch_internal_logger_new_header] 
	                                                @snapshot_time_new = @snapshot_time_new OUTPUT,
	                                                @snapshot_type_id = @snapshot_type_id,
                                                    @sql_instance = @sql_instance,
                                                    @snapshot_time = @snapshot_time;

                                            if @snapshot_type_id = 1
                                                begin
                                                    set @snapshot_time_previous = [dbo].[ufn_sqlwatch_get_previous_snapshot_time] ( @snapshot_type_id, @sql_instance, @snapshot_time );

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_os_performance_counters]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_time_previous = @snapshot_time_previous,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_os_process_memory]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_os_schedulers]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_os_wait_stats]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_time_previous = @snapshot_time_previous,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_os_memory_clerks]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_io_virtual_file_stats]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_time_previous = @snapshot_time_previous,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 2
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_space_usage_database]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 3
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_db_missing_index_details]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 6
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_xes_waits]
                                                        @data = @message_body,
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 7
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_xes_long_queries]
                                                        @data = @message_body,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 9
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_xes_blockers_and_deadlocks]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id = @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 10
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_xes_diagnostics]
                                                        @data = @message_body,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 14
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_db_index_usage_stats]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 16
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_sysjobhistory]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 17
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_space_usage_os_volume]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 22
                                                begin
                                                    set @snapshot_time_previous = [dbo].[ufn_sqlwatch_get_previous_snapshot_time] ( @snapshot_type_id, @sql_instance, @snapshot_time );

                                                    exec [dbo].[usp_sqlwatch_internal_logger_space_usage_table]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_time_previous = @snapshot_time_previous,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 26
                                                begin
                                                    set @snapshot_time_previous = [dbo].[ufn_sqlwatch_get_previous_snapshot_time] ( @snapshot_type_id, @sql_instance, @snapshot_time );

                                                    exec [dbo].[usp_sqlwatch_internal_logger_system_configuration]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_time_previous = @snapshot_time_previous,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 27
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_exec_procedure_stats]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 28
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_exec_query_stats]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;
                                                            
                                            else if @snapshot_type_id = 29
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_hadr_database_replica_states]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            else if @snapshot_type_id = 30
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_exec_sessions]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;

                                                    exec [dbo].[usp_sqlwatch_internal_logger_dm_exec_requests]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance,
                                                        @timezoneoffset = @timezoneoffset;
                                                end;

                                            else if @snapshot_type_id = 32
                                                begin
                                                    exec [dbo].[usp_sqlwatch_internal_logger_sysjobhistory]
                                                        @xdoc = @xdoc,
                                                        @snapshot_time = @snapshot_time,
                                                        @snapshot_type_id =  @snapshot_type_id,
                                                        @sql_instance = @sql_instance;
                                                end;

                                            exec sp_xml_removedocument @xdoc;
                                                    
                                            if @@TRANCOUNT > 0
                                                begin
                                                    commit transaction;
                                                end;

                                        end try
                                        begin catch

                                            if XACT_STATE() = 1 and @@TRANCOUNT > 0
                                                begin
                                                    --when we hit an error loading perf data we will dismiss that message and move on.
                                                    --otheriwse a single broken message may hold up the queue if we keep rolling back
                                                    --and since its a performance data, we do not care about losing few snapshots
                                                    --but we do care about not blowing the database and server
                                                    commit transaction
                                                end;

                                            else if XACT_STATE() = -1 and @@TRANCOUNT > 0
                                                begin
                                                    --only rollback if the transaction is broken
                                                    rollback transaction
                                                end;

                                            exec sp_xml_removedocument @xdoc;

                                            set @process_message = FORMATMESSAGE('Error whilst processing message %s in group %s for @snapshot_type_id %i.',@conversation_handle_txt, @conversation_group_id_txt, @snapshot_type_id);

                                            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                            @proc_id = @@PROCID,
					                            @process_stage = '4A6E9960-5C80-4674-8672-E877DF2FD9CA',
					                            @process_message = @process_message ,
					                            @process_message_type = 'ERROR',
                                                @message_payload = @message_body;

                                        end catch;

                                    end;

                            end;

                        else if @message_type_name = N'mtype_sqlwatch_meta'
                            begin

                                if (@message_body.exist('/MetaDataSnapshot')=0)
                                    begin
                                        if @@TRANCOUNT > 0
                                            begin
                                                commit transaction;
                                            end;
                                        break;
                                    end;

                                exec sp_xml_preparedocument @xdoc OUTPUT, @message_body;

                                select @metadataname = meta_data,
                                        @sql_instance = sql_instance
                                from openxml (@xdoc, '/MetaDataSnapshot/snapshot_header/row',1) 
                                with (
	                                meta_data nvarchar(50),
                                    snapshot_time datetime2(0),
	                                sql_instance varchar(32)
                                )

                                begin try

                                    if @metadataname = 'meta_server'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_server]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'sys_databases'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_database]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'sys_master_files'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_master_file]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'dm_os_memory_clerks'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_dm_os_memory_clerks]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'dm_os_wait_stats'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_dm_os_wait_stats]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'dm_os_performance_counters'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_dm_os_performance_counters]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    else if @metadataname = 'sys_jobs'
                                        begin
                                            exec [dbo].[usp_sqlwatch_internal_meta_add_job]
                                                @xdoc = @xdoc,
                                                @sql_instance = @sql_instance;
                                        end;

                                    exec sp_xml_removedocument @xdoc;

                                    if @@TRANCOUNT > 0
                                        begin
                                            commit transaction;
                                        end;

                                end try
                                begin catch
                                    if XACT_STATE() = 1 and @@TRANCOUNT > 0
                                        begin
                                            --when we hit an error loading perf data we will dismiss that message and move on.
                                            --otheriwse a single broken message may hold up the queue if we keep rolling back
                                            --and since its a performance data, we do not care about losing few snapshots
                                            --but we do care about not blowing the database and server
                                            commit transaction
                                        end;

                                    else if XACT_STATE() = -1 and @@TRANCOUNT > 0
                                        begin
                                            --only rollback if the transaction is broken
                                            rollback transaction
                                        end;

                                    exec sp_xml_removedocument @xdoc;

                                    set @error_message = ERROR_MESSAGE();

                                    exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                    @proc_id = @@PROCID,
					                    @process_stage = '47FDA669-7068-459D-952D-79BC0BDD9B5C',
					                    @process_message = @error_message,
					                    @process_message_type = 'ERROR',
                                        @message_payload = @message_body;

                                end catch;
                            end;

                        else if @message_type_name = N'mtype_sqlwatch_end'
                            or  @message_type_name = N'DEFAULT'
                            or  @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
                            begin                        
                                end conversation @conversation_handle;

                                if @@TRANCOUNT > 0
                                    begin
                                        commit transaction;
                                    end;
                            end;

                        else if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
                            begin
                                ;
                                with XMLNAMESPACES ('http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS ssb)
                                select
                                    @error_number = @message_body.value('(//ssb:Error/ssb:Code)[1]', 'INT'),
                                    @error_message = @message_body.value('(//ssb:Error/ssb:Description)[1]','NVARCHAR(MAX)');
                                    
                                set @process_message = FORMATMESSAGE('The converstaion has returned an error (%i) %s',@error_number,@error_message);

                                exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                @proc_id = @@PROCID,
					                @process_stage = 'F679058E-6C02-483D-BF55-56361E003F7B',
					                @process_message = @process_message ,
					                @process_message_type = 'ERROR',
                                    @message_payload = @message_body;

                                if @@TRANCOUNT > 0
                                    begin
                                        commit transaction;
                                    end;

                            end;
                    end
            end;

        if @@TRANCOUNT > 0
            begin
                commit transaction;
            end;

    end try
    begin catch
        select  @error_number = ERROR_NUMBER(),
                @error_message = ERROR_MESSAGE()
                    
        if XACT_STATE() = -1 and @@TRANCOUNT > 0
            begin
                --this is the only time when we will rollback as this would indicate problems with the queue processor, not the data in the queue
                --not that rolling back queue will eventually trigger poison message protection and stop the queue altogether
                rollback transaction;
            end
        raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @this_procedure_name, @error_number, @error_message);
    end catch;
end;