CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_restart_queues]
as
begin

    declare @sql varchar(max) = '',
            @process_message varchar(4000);

    -- end all conversations:
    -- Stop and clean all sqlwatch conversations in the database. 
    -- Whilst this is not normally recommended as it may abrubtly stopped all conversations, it is safe here as we have stopped all queues above.
    set @sql = ''
    select @sql = @sql + '
    end conversation ''' + convert(varchar(max),conversation_handle) + ''';'
    from sys.conversation_endpoints
    where far_service like 'sqlwatch%'
    and state_desc <> 'CLOSED' -- these will be cleaned up by SQL Server

    exec (@sql)

    waitfor delay '00:00:02'

    exec (@sql)

    waitfor delay '00:00:02'

    --reseed timer queues
    declare @conversation_handle uniqueidentifier;

end;

