CREATE PROCEDURE [dbo].[usp_sqlwatch_local_logger_enqueue_metadata_snapshot]
	@metadata nvarchar(50),
	@cid uniqueidentifier
AS
begin
	set nocount on;
	declare @message_body xml;

	--this procedure is only intended to run for local collection when SqlWatchCollect is not used.
	if dbo.ufn_sqlwatch_get_config_value(24,null) = 0
		begin
			
			exec [dbo].[usp_sqlwatch_internal_get_data_metadata_snapshot_xml]
				@metadata = @metadata,
				@metadata_xml = @message_body output;

			SEND ON CONVERSATION @cid
				MESSAGE TYPE [mtype_sqlwatch_meta] (@message_body);

		end;

end;