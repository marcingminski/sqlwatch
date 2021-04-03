CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated]
as
begin
	set nocount on;

    declare @conversation_handle    uniqueidentifier,
            @message_type_name      nvarchar(128),
            @message_body           xml,
            @procedure_name         nvarchar(128),
            @error_number           int,
            @error_message          nvarchar(max),
            @this_procedure_name    nvarchar(128),
            @timer                  int

        begin try;

            set @this_procedure_name = OBJECT_NAME(@@PROCID);
            
            -- get items from our queue
            receive top(1) 
                  @conversation_handle = [conversation_handle]
                , @message_type_name = [message_type_name]
                , @message_body = cast([message_body] as xml)
                from sqlwatch_exec_queue;
            
            -- the xml message body will contain our procedure to execute
            select @procedure_name = @message_body.value('(//procedure/name)[1]', 'nvarchar(128)');

            if @procedure_name is not null
                begin
                    --catch execution of the procedure
                    if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
                    begin
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

                    -- now we need to requeue our messsage so it executes again in the next n seconds
                    select @timer = [timer_seconds] 
                    from [dbo].[sqlwatch_config_activated_procedures] 
                    where [procedure_name] = @procedure_name

                    begin conversation timer (@conversation_handle) timeout = @timer;
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