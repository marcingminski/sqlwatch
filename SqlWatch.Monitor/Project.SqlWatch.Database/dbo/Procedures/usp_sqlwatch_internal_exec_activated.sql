CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated]
    @queue nvarchar(128),
    @procedure_name nvarchar(128),
    @timer int
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
            
            -- the xml message body will contain our procedure to execute
            --select @procedure_name = @message_body.value('(//procedure/name)[1]', 'nvarchar(128)');

            if @conversation_handle is not null
                begin
                    --catch execution of the procedure
                    if @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
                    begin
                        begin conversation timer (@conversation_handle) timeout = @timer;
                        
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