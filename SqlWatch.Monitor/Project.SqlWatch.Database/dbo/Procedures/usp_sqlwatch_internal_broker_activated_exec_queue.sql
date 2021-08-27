CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_activated_exec_queue]
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
            @timer                  int,
            @timestart              datetime2(7),
            @timerend               datetime2(7),
            @process_message        varchar(4000),
            @ext_collector          bit,
            @ext_collector_warn     varchar(4000),
            @conversation_handle_txt varchar(255),
            @conversation_group_id_txt  varchar(255),
            @process_message_type   varchar(50) = 'INFO',
            @cid                    uniqueidentifier,
            @timetakenms            int,
            @end_handle             bit = 0,
            @snapshots_cursor       as CURSOR,
            @snapshot_type_id       tinyint,
            @dummy                  int,
            @lock_result            int,
            @timer_type             char(1),
            @timerdays              varchar(27),
            @timerhours             varchar(5),
            @timervalidfrom         datetime2(0),
            @timervalidto           datetime2(0),
            @timerenabled           bit
            ;

        begin try;

            set @this_procedure_name = OBJECT_NAME(@@PROCID);
            set @ext_collector = dbo.ufn_sqlwatch_get_config_value(24, default);

            -- get items from our queue            
            receive top(1)
                  @conversation_handle = [conversation_handle]
                , @message_type_name = [message_type_name]
                , @message_body = cast([message_body] as xml)
		        , @conversation_group_id = [conversation_group_id]
                , @conversation_handle_txt = convert(varchar(255),[conversation_handle])
                , @conversation_group_id_txt = convert(varchar(255),[conversation_group_id])
                from dbo.sqlwatch_exec;
            
            -- if procedure is in the message body, it means we're running async execution rather than timer
            set @procedure_name = @message_body.value('(//procedure/name)[1]', 'nvarchar(128)');

            if @conversation_handle is not null
                begin
                    begin try

                        set @process_message = null;
                        set @timestart = SYSDATETIME();

                        if  @message_type_name = N'DEFAULT' and @procedure_name is not null
                            begin

                                exec @procedure_name;

                                set @timerend = SYSDATETIME();
                                set @timetakenms = datediff(ms,@timestart,SYSDATETIME());

                                set @process_message = FORMATMESSAGE('Message Type: %s; Procedure: %s; Time Taken: %i ms',@message_type_name,@procedure_name,@timetakenms);
                            end

                        else if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
                            begin
                                
                                -- This is safe, do not worry.
                                -- sp_getapplock creates a "fake" lock that we can then refer to, it is not actually locking any physical objects
                                -- becuase we do not want to run the same timer multiple times, we are going to bail if another instance is running
                                -- this would often be solved with a "dbo.running" table and maintain records there but Sql Server gives us such "table" with sp_getapplock. 

                                -- however, we also only put out a new time after the work has completed so theoretically there is never any risk of re-scheduling the timer before it's done.
                                -- we are doing so to always give the server the breathing space. 
                                -- Assume the performance collector takes 4 seconds to run. If we schedule it to run exactly ever 5 seconds we are only going to have 1 second gap between runs and thus more work/cpu usage:
                                -- If we schedule it to run 5 seconds afters it has finished, we are going to have a 5 second gap but the collections may not be consistent throughout the time.
                                -- The timers will also shift over time, however this is less critical. The aim is to make sure the server is not overloaded. 

                                exec @lock_result = sp_getapplock 
                                    @Resource = @conversation_group_id_txt
                                    , @LockMode = 'Exclusive'
                                    , @LockOwner = 'Session'
                                    , @DbPrincipal = 'dbo' --becuase broker
                                    , @LockTimeout = 0;

                                if @lock_result >= 0
                                    begin

                                        -- timer ids must match [dbo].[sqlwatch_config_snapshot_timer]
                                        select 
                                            @timer = timer_seconds
                                            , @timer_type = timer_type
                                            , @timerdays = timer_active_days
                                            , @timerhours = timer_active_hours_utc
                                            , @timervalidfrom = timer_active_from_date_utc
                                            , @timervalidto = timer_active_to_date_utc
                                            , @timerenabled = timer_enabled
                                        from dbo.[sqlwatch_config_timer] (nolock)
                                        where timer_id = @conversation_group_id
                                        ;

                                        -- If using external collector, end any local Collectors.
                                        if @ext_collector = 1 and @timer_type = 'C'
                                            begin
                                                set @process_message = FORMATMESSAGE('Using external data collector. Ending conversation %s in Group %s',@conversation_handle_txt,@conversation_group_id_txt);

                                                exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                                @proc_id = @@PROCID,
					                                @process_stage = 'E99A5A9D-CB7F-42BF-93B1-EA792E01A6E7',
					                                @process_message = @process_message,
					                                @process_message_type = 'WARNING';

                                                end conversation @conversation_handle;                      

                                                if @@TRANCOUNT > 0
                                                    begin
                                                        commit transaction;
                                                    end;
                                                
                                                return;
                                            end

                                        if @timerenabled = 1
                                            and charindex(format(getutcdate(),'ddd'),@timerdays) > 0
                                            and datepart(hour,getutcdate()) between substring(@timerhours,1,2) and substring(@timerhours,4,2)
                                            and getutcdate() between @timervalidfrom and @timervalidto
                                            begin

                                                --Internal processing. Always runs whether we use SqlWatchCollect.exe or not
                                                if @conversation_group_id = 'CD0AA425-FBF6-410C-B216-9809B729C88A' and @ext_collector = 0
                                                    begin
                                                        -- This is the only exception where the logger procedure runs as internal type
                                                        -- This is because when the @ext_collector is enabled, SqlWatchCollect.exe will run the proc for us
                                                        -- but since this is a helper proc that does not return anything or take @snapshot_type_id param it cannot be run as an actual collector
                                                        -- and becuase most of the execution engine is dynamic, I would have to build this exclusion in C# which would be less transparent in a compiled program.
                                                        -- It also HAS to run every 1 minute so it has its own timer.
                                                        exec dbo.usp_sqlwatch_logger_ring_buffer_scheduler_monitor;
                                                    end;

                                                else if @conversation_group_id = 'A5A7457B-865B-426D-AB4B-9DBC7257297B'
                                                    begin
                                                        exec [dbo].[usp_sqlwatch_internal_logger_broker_queue];
                                                        exec [dbo].[usp_sqlwatch_internal_broker_update_queue_status];
                                                    end;

                                                else if @conversation_group_id = '290C4FF4-90BE-45C0-BC8F-8EE0F17EDF51'
                                                    begin
                                                        exec dbo.usp_sqlwatch_internal_broker_dialog_cleanup;
                                                    end;

                                                else if @conversation_group_id = 'C4A9DF05-5E4C-4F4C-B292-B7D291A93B6F'
                                                    begin
                                                        exec dbo.usp_sqlwatch_internal_process_checks;
                                                    end;

                                                else if @conversation_group_id = '154FE9BE-4CCF-450E-8270-E718C12408C7'
                                                    begin
                                                        exec dbo.usp_sqlwatch_internal_expand_checks;
                                                    end;

                                                else if @conversation_group_id = 'FCD8FAD8-B598-4313-8BF9-1648A6F15869'
                                                    begin
                                                        exec dbo.usp_sqlwatch_internal_retention;
                                                    end;

                                                else if @conversation_group_id in ('EFB8A583-B238-4468-AAEB-6EF8DE45029A','A44B4166-3D12-49D3-B8DA-F793B75AE159')
                                                    begin
                                                        exec [dbo].[usp_sqlwatch_trend_perf_os_performance_counters] @timer_id = @conversation_group_id
                                                    end;

                                                -- Performance Collector. Runs only if we do not use SqlWatchCollect.exe
                                                -- The piece of code on top decides whether to put out a new message with this timer or not.
                                                -- If it does, we are going to run the below, if it does not , there will be no message
                                                -- in this particular group to run.
                                                else if @conversation_group_id = 'B7686F08-DCAF-4EFC-94E8-3BD8D2C8E8A5'
                                                    and dbo.ufn_sqlwatch_get_config_value(25,null) = 1
                                                    begin
                                                        exec [dbo].[usp_sqlwatch_local_meta_add];
                                                    end;

                                                else if @conversation_group_id in (
                                                    'B273076A-5D10-4527-909F-955707905890',
                                                    'A2719CB0-D529-46D6-8EFE-44B44676B54B',
                                                    'FDA18576-D2DC-4143-8BF1-CDDF1BAA72CB',
                                                    'F65F11A7-25CF-4A4D-8A4F-C75B03FE083F',
                                                    'E623DC39-A79D-4F51-AAAD-CF6A910DD72A',
                                                    'D6AFF9F8-3CC3-4714-BCAA-7FC7A8E7AC5C'
                                                ) and @ext_collector = 0 and dbo.ufn_sqlwatch_get_config_value(25,null) = 1
                                                    begin
                                                        exec [dbo].[usp_sqlwatch_internal_broker_dialog_new]
                                                            @cid = @cid output;
                                                    
                                                        set @snapshots_cursor = cursor FAST_FORWARD for
                                                        select snapshot_type_id
                                                        from dbo.sqlwatch_config_snapshot_type (nolock)
                                                        where timer_id = @conversation_group_id
                                                        and snapshot_type_id != 17 --wmi colletor must be done at the OS level, cannot do via T-SQL.
                                                        and [collect] = 1;

                                                        open @snapshots_cursor
                                                        fetch next from @snapshots_cursor into @snapshot_type_id;

                                                        while @@FETCH_STATUS = 0
                                                            begin
                                                                exec [dbo].[usp_sqlwatch_local_logger_enqueue_collection_snapshot] 
                                                                    @snapshot_type_id = @snapshot_type_id, 
                                                                    @cid = @cid;
                                                                fetch next from @snapshots_cursor into @snapshot_type_id;
                                                            end;

                                                        close @snapshots_cursor;
                                                        deallocate @snapshots_cursor;

                                                        exec [dbo].[usp_sqlwatch_internal_broker_dialog_end]
                                                            @cid = @cid;
                                                    end;
                                        
                                                --remove the lock now
                                                exec sp_releaseapplock 
                                                    @Resource = @conversation_group_id_txt
                                                    , @DbPrincipal = 'dbo'
                                                    , @LockOwner = 'Session';

                                                set @timerend = SYSDATETIME();
                                                set @timetakenms = datediff(ms,@timestart,@timerend);
                                                set @process_message = FORMATMESSAGE('Message Type: %s; Timer: %i; Time Taken: %i ms',@message_type_name,@timer,@timetakenms);

                                                exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                                @proc_id = @@PROCID,
					                                @process_stage = '25C5B6CE-BBBC-4AA9-A2B4-9D9C654F6CBA',
					                                @process_message = @process_message,
					                                @process_message_type = 'VERBOSE';

                                            end;

                                        set @process_message = formatmessage('Scheduling timer %s with timeout %i',@conversation_group_id_txt, @timer)

                                        exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                        @proc_id = @@PROCID,
					                        @process_stage = '02930747-1DE4-4E22-B9DB-95B3564F4B2B',
					                        @process_message = @process_message,
					                        @process_message_type = 'VERBOSE';

                                        begin conversation timer (@conversation_handle) timeout = @timer;
                                    end;
                                else 
                                    begin
                                        set @process_message  = FORMATMESSAGE('Another instance of timer %s is already running. Lock Request Result was: %i', @conversation_group_id_txt, @lock_result);

                                        exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                        @proc_id = @@PROCID,
					                        @process_stage = 'A8147646-2183-4EB3-9958-1F2FD4A11341',
					                        @process_message = @process_message,
					                        @process_message_type = 'WARNING';
                                    end;

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

                                set @process_message = FORMATMESSAGE('The converstaion %s has returned an error (%i) %s',@conversation_handle_txt,@error_number,@error_message);

                                exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					                @proc_id = @@PROCID,
					                @process_stage = '38BCE6CF-B833-4730-9BB3-DB1F69D213E2',
					                @process_message = @process_message,
					                @process_message_type = 'ERROR'

                                end conversation @conversation_handle;
                            end;

                        else if (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
                            begin
                                end conversation @conversation_handle;
                            end;

                    end try
                    begin catch

                        --remove the lock now
                        if (APPLOCK_MODE( 'dbo' , @conversation_group_id_txt , 'Session' ) = 'Exclusive')
                            begin
                                exec sp_releaseapplock 
                                    @Resource = @conversation_group_id_txt
                                    , @DbPrincipal = 'dbo'
                                    , @LockOwner = 'Session';
                            end;

                        select  @error_number = ERROR_NUMBER(),
                                @error_message = ERROR_MESSAGE()
                            
                        if XACT_STATE() in (-1,1)
                            begin
                                rollback transaction
                            end 

                        set @process_message = FORMATMESSAGE('Error whilst processing message (%s) in Group %s',@conversation_handle_txt, @conversation_group_id_txt);

                        exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					        @proc_id = @@PROCID,
					        @process_stage = '963690C9-4DBC-49DE-8E6F-B4C39EF32B1D',
					        @process_message = @process_message,
					        @process_message_type = 'ERROR'

                        end conversation @conversation_handle

                    end catch
                end
            else
                begin
                    if XACT_STATE() = 1
                        begin
                            --commit queue and remove the message:
                            commit transaction
                        end
                end
        end try
        begin catch
            select  @error_number = ERROR_NUMBER(),
                    @error_message = ERROR_MESSAGE()
                    
            if XACT_STATE() in (-1,1)
                begin
                    rollback;
                    if @conversation_handle is not null
                        begin
                            end conversation @conversation_handle;
                        end;
                end
            raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @this_procedure_name, @error_number, @error_message);
        end catch
end