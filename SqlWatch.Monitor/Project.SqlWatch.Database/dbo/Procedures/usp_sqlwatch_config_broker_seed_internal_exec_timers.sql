CREATE PROCEDURE [dbo].[usp_sqlwatch_config_broker_seed_internal_exec_timers]
as
begin
    declare @conversation_handle uniqueidentifier,
            @conversation_cursor cursor,
            @init_delay int = 1,
            @timer_id uniqueidentifier,
            @process_message varchar(4000);
            ;

     ------------------------------------------------------------------------------------------
     -- INTERNAL PROCESSING GROUPS 
     -- These are responsible for internal maintenance such as retention and trends and
     -- will always be active
     -----------------------------------------------------------------------------------------
           set @conversation_cursor = cursor fast_forward for
            select timer_id
            from dbo.sqlwatch_config_timer t
            --only if there are no existing conversations:
            outer apply (
	            select cnt=count(*)
	            from sys.conversation_endpoints e with (nolock) 
	            where conversation_group_id = t.timer_id 
	            ) a
            where t.timer_type = 'I'
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

                    set @init_delay+=1;

                    fetch next from @conversation_cursor into @timer_id;
                end;

            close @conversation_cursor;
            deallocate @conversation_cursor;
end;