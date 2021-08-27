CREATE PROCEDURE [dbo].[usp_sqlwatch_config_broker_seed_collection_exec_timers]
as
begin
    declare @conversation_handle uniqueidentifier,
            @conversation_cursor cursor,
            @init_delay int = 1,
            @timer_id uniqueidentifier,
            @process_message varchar(4000);
            ;

    ------------------------------------------------------------------------------------------
    -- PERFORMANCE COLLECTION GROUPS
    -- these are responsible for collecting performance data and will be switched off
    -- when using SqlWatchCollect.exe
    ------------------------------------------------------------------------------------------
    if dbo.ufn_sqlwatch_get_config_value(24, default) = 0
        begin

            set @conversation_cursor = cursor fast_forward for
            select timer_id
            from dbo.sqlwatch_config_timer t
            --only if there are no existing conversations:
            outer apply (
	            select cnt=count(*)
	            from sys.conversation_endpoints e with (nolock) 
	            where conversation_group_id = t.timer_id 
	            ) a
            where t.timer_type = 'C'
            and a.cnt = 0;

            open @conversation_cursor
            fetch next from @conversation_cursor into @timer_id;

            while @@FETCH_STATUS = 0
                begin

                    begin dialog conversation @conversation_handle
                        from service [sqlwatch_exec]
                        to service N'sqlwatch_exec', N'current database'
                        with encryption = off,
                        RELATED_CONVERSATION_GROUP = @timer_id;

                    --initial delay:
                    begin conversation timer (@conversation_handle) timeout = @init_delay;

                    set @init_delay+=2;

                    fetch next from @conversation_cursor into @timer_id;
                end;

            close @conversation_cursor;
            deallocate @conversation_cursor;

        end
    else
        begin
            set @process_message = FORMATMESSAGE('Using external data collector. Performance collection via broker will not be enabled');
            print @process_message;

            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
				@proc_id = @@PROCID,
				@process_stage = '2CCA391F-061E-4E1F-B3E3-FD6911D9845C',
				@process_message = @process_message,
				@process_message_type = 'WARNING';
        end;
end;