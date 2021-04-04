CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated]
    @queue nvarchar(128),
    @procedure_name nvarchar(128) = null,
    @timer int = null
as
begin
	set nocount on;

    if @timer is null and @queue not like '%sqlwatch_exec_async%'
        begin
            -- no timer given but queue given, assume we're specifying queue other than the exec async and we should have a timer
            Print 'Timer must be specified for queues other than [dbo].[sqlwatch_exec_async]'
            return
        end



    declare @conversation_handle    uniqueidentifier,
            @message_type_name      nvarchar(128),
            @message_body           xml,
            @error_number           int,
            @error_message          nvarchar(max),
            @this_procedure_name    nvarchar(128),
            @sql                    nvarchar(max),
            @sql_params             nvarchar(max)

        begin try;

            set @this_procedure_name = OBJECT_NAME(@@PROCID);
            
            -- get items from our queue
            set @sql = '
            receive top(1)
                  @conversation_handle_out = [conversation_handle]
                , @message_type_name_out = [message_type_name]
                , @message_body_out = cast([message_body] as xml)
                from ' + @queue;

            set @sql_params = N'@conversation_handle_out uniqueidentifier OUT, @message_type_name_out nvarchar(128) OUT, @message_body_out xml OUT';

            exec sp_executesql 
                  @sql
                , @sql_params
                , @conversation_handle_out = @conversation_handle OUT
                , @message_type_name_out = @message_type_name OUT
                , @message_body_out = @message_body OUT
            
            -- if procedure not passed, parse the message body and extract the procedure name.
            -- this will only work if we have put a message out that contains the body. 
            -- this will not work for timer based conversations as they don't carry the payload.
            if @procedure_name is null
                begin
                    set @procedure_name = @message_body.value('(//procedure/name)[1]', 'nvarchar(128)');
                end

            if @conversation_handle is not null and @procedure_name is not null
                begin
                    --put out another timer for timed messages, otherwise just execute async:
                    if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
                        begin
                            if @timer is not null
                                begin
                                    begin conversation timer (@conversation_handle) timeout = @timer;
                                end
                            else
                                begin
                                    Print 'Message of type DialogTimer must have a @timer'
                                    return                                
                                end
                        end

                        
                    begin try
                        exec @procedure_name;
                    end try
                    begin catch
                        select  @error_number = ERROR_NUMBER(),
                                @error_message = ERROR_MESSAGE()
                            
                        if @@TRANCOUNT > 0
                            begin
                                rollback
                            end
                        raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @procedure_name, @error_number, @error_message);
                    end catch
                end
            else
                begin
                    if @@TRANCOUNT > 0
                        begin
                            rollback
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
                end
            raiserror(N'Error whilst executing SQLWATCH Procedure %s: %i: %s', 16, 10, @this_procedure_name, @error_number, @error_message);
        end catch
end