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
        from service sqlwatch_invoke_5s
        to service N'sqlwatch_invoke_5s', N'current database'
        with encryption = off;
    begin conversation timer (@conversation_handle) timeout = 5;

    begin dialog conversation @conversation_handle
        from service sqlwatch_invoke_1m
        to service N'sqlwatch_invoke_1m', N'current database'
        with encryption = off;
    begin conversation timer (@conversation_handle) timeout = 60;

    begin dialog conversation @conversation_handle
        from service sqlwatch_invoke_10m
        to service N'sqlwatch_invoke_10m', N'current database'
        with encryption = off;
    begin conversation timer (@conversation_handle) timeout = 600;

    begin dialog conversation @conversation_handle
        from service sqlwatch_invoke_60m
        to service N'sqlwatch_invoke_60m', N'current database'
        with encryption = off;
    begin conversation timer (@conversation_handle) timeout = 3600;

