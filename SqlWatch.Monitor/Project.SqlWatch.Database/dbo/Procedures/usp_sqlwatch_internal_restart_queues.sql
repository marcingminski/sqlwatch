CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_restart_queues]
as

declare @sql varchar(max) = '';

-- disable all queues:
select @sql = @sql + 'ALTER QUEUE ' + name + ' WITH STATUS = OFF;' + char(10) 
from sys.service_queues
where name like 'sqlwatch%'

exec (@sql)

waitfor delay '00:00:05'

-- clean up all conversations:
-- Stop and clean all sqlwatch conversations in the database. 
-- Whilst this is not normally recommended as it may abrubtly stopped all conversations, it is safe here as we have stopped all queues above.
set @sql = ''
select @sql = @sql + '
end conversation ''' + convert(varchar(max),conversation_handle) + ''' WITH CLEANUP;'
from sys.conversation_endpoints
where far_service like 'sqlwatch%'
and state_desc <> 'CLOSED' -- these will be cleaned up by SQL Server

exec (@sql)

waitfor delay '00:00:05'

--restart queues
select @sql = @sql + 'ALTER QUEUE ' + name + ' WITH STATUS = ON;' + char(10) 
from sys.service_queues
where name like 'sqlwatch%'

exec (@sql)

waitfor delay '00:00:05'

--reseed timer queues
    declare @conversation_handle uniqueidentifier;

    begin dialog conversation @conversation_handle
        from service [sqlwatch_exec]
        to service N'sqlwatch_exec', N'current database'
        with encryption = off,
             RELATED_CONVERSATION_GROUP = 'B273076A-5D10-4527-909F-955707905890';
    
    --initial delay:
    begin conversation timer (@conversation_handle) timeout = 5;

    begin dialog conversation @conversation_handle
        from service [sqlwatch_exec]
        to service N'sqlwatch_exec', N'current database'
        with encryption = off,
             RELATED_CONVERSATION_GROUP = 'A2719CB0-D529-46D6-8EFE-44B44676B54B';

    --initial delay:
    begin conversation timer (@conversation_handle) timeout = 60;

    begin dialog conversation @conversation_handle
        from service [sqlwatch_exec]
        to service N'sqlwatch_exec', N'current database'
        with encryption = off,
             RELATED_CONVERSATION_GROUP = 'F65F11A7-25CF-4A4D-8A4F-C75B03FE083F';

    --initial delay:
    begin conversation timer (@conversation_handle) timeout = 70;

    begin dialog conversation @conversation_handle
        from service [sqlwatch_exec]
        to service N'sqlwatch_exec', N'current database'
        with encryption = off,
             RELATED_CONVERSATION_GROUP = 'E623DC39-A79D-4F51-AAAD-CF6A910DD72A';
    
    --initial delay:
    begin conversation timer (@conversation_handle) timeout = 90;

