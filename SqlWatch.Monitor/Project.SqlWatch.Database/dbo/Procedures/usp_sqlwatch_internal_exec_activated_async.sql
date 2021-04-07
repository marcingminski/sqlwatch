CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated_async]
    @procedure_name nvarchar(128)
as

    declare @conversation_handle uniqueidentifier,
            @xmlBody xml;

    set @xmlBody = (
            select @procedure_name as [name]
            for xml path('procedure')
            , type);

    begin dialog conversation @conversation_handle
        from service sqlwatch_exec
        to service N'sqlwatch_exec', N'current database'
        with encryption = off,
        lifetime = 60;

    send on conversation @conversation_handle (@xmlBody);
        

