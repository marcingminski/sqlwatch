CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_dialog_new]
	@cid uniqueidentifier output,
    @lifetime int = 3600,
    @from_service nvarchar(128) = 'sqlwatch_collector',
    @to_service nvarchar(128) = 'sqlwatch_collector',
    @contract nvarchar(128) = 'sqlwatch_collector'
AS
begin

    declare @process_message nvarchar(255),
            @cid_txt nvarchar(128);

    BEGIN DIALOG @cid
        FROM SERVICE @from_service
        TO SERVICE @to_service , N'current database'
        ON CONTRACT @contract
        WITH ENCRYPTION = OFF,
        LIFETIME = @lifetime;

    set @cid_txt = convert(nvarchar(128),@cid);

	set @process_message = FORMATMESSAGE('Created new dialog (%s)', @cid_txt);

	exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
			@proc_id = @@PROCID,
			@process_stage = '34E4CEF2-599E-41FE-B779-02722084E8AB',
			@process_message = @process_message,
			@process_message_type = 'VERBOSE';

end;