CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_update_queue_status]
	@queue_name nvarchar(128) = 'sqlwatch_collector'

AS
begin

	declare @queue_status smallint,
			@process_message nvarchar(128);

	select @queue_status = is_receive_enabled from sys.service_queues (nolock) where name = @queue_name;

	update dbo.sqlwatch_config
		set config_value = @queue_status
		where config_id = 25;

	if @queue_status = 0
		begin
			set @process_message = FORMATMESSAGE('The receiving queue %s is disabled.', @queue_name);

            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
				@proc_id = @@PROCID,
				@process_stage = '5F225003-35A1-4287-888A-1307B8E2629B',
				@process_message = @process_message,
				@process_message_type = 'ERROR';
		end
	else
		begin
			set @process_message = FORMATMESSAGE('The receiving queue %s is enabled.', @queue_name);

            exec [dbo].[usp_sqlwatch_internal_app_log_add_message]
				@proc_id = @@PROCID,
				@process_stage = '5F225003-35A1-4287-888A-1307B8E2629B',
				@process_message = @process_message,
				@process_message_type = 'INFO';
		end;

end;