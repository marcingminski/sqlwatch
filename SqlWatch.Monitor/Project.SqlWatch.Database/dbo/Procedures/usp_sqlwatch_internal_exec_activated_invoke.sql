CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated_invoke]
as

--this procedure is used to start conversation dialogues

declare @conversation_handle uniqueidentifier, 
        @procedure_name nvarchar(128),
        @xmlBody xml;

declare cur_activated_procs cursor for
select [procedure_name] from [dbo].[sqlwatch_config_activated_procedures]

open cur_activated_procs
fetch next from cur_activated_procs
into @procedure_name

while @@FETCH_STATUS = 0
    begin

        begin dialog conversation @conversation_handle
        from service sqlwatch_exec_service
        to service N'sqlwatch_exec_service', N'current database'
        with encryption = off;

        --push procedure name in the message body so we can retrieve it later
	    select @xmlBody = (
                select @procedure_name as [name]
                for xml path('procedure'), type);

        send on conversation @conversation_handle (@xmlBody);

        fetch next from cur_activated_procs
        into @procedure_name
    end

close cur_activated_procs
deallocate cur_activated_procs

