CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_exec_activated_invoke]
as

--this procedure is used to start conversation dialogues

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

