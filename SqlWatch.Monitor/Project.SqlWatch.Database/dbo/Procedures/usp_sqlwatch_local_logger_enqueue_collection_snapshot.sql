CREATE PROCEDURE [dbo].[usp_sqlwatch_local_logger_enqueue_collection_snapshot]
	@snapshot_type_id tinyint,
	@cid uniqueidentifier
AS
begin
	set nocount on;
	declare @message_body xml;

	--this procedure is only intended to run for local collection when SqlWatchCollect is not used.
	if dbo.ufn_sqlwatch_get_config_value(24,null) = 0
		begin
			
			exec [dbo].[usp_sqlwatch_internal_get_data_collection_snapshot_xml]
				@snapshot_type_id = @snapshot_type_id,
				@snapshot_data_xml = @message_body output;

			if @message_body is null
				begin
					declare @process_message nvarchar(max);
					set @process_message = FORMATMESSAGE( 'Got null @message_body for @snapshot_type_id: %i', @snapshot_type_id);
					
                    exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
					    @proc_id = @@PROCID,
					    @process_stage = '989FB03E-3828-4A54-AFFB-E88E0FA4F94CA',
					    @process_message = @process_message,
					    @process_message_type = 'ERROR';
				end;

			SEND ON CONVERSATION @cid
				MESSAGE TYPE [mtype_sqlwatch_collector] (@message_body);

		end;

end;
