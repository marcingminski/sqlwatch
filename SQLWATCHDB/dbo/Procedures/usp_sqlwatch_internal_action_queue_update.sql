CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_action_queue_update]
	@queue_item_id bigint,
	@exec_status varchar(50),
	@error nvarchar(max) = null
as
begin

	update [dbo].[sqlwatch_meta_action_queue] 
		set [exec_status] = case when @exec_status = 'ERROR' and isnull([retry_count],0) < 5 then 'RETRYING' else @exec_status end, --try retry errors up to 5 attempts
			[exec_time_end] = sysdatetime(),
			[retry_count] = case when @exec_status = 'ERROR' then isnull([retry_count],0) + 1 else [retry_count] end --increase retry counter
	where queue_item_id = @queue_item_id

	Print 'exec_status: ' + @exec_status + ' (queue_item_id: ' + convert(varchar(100),@queue_item_id) + ')'

	set @exec_status = case when @exec_status = 'OK' then 'INFO' else @exec_status end

	if @exec_status = 'INFO' and @error = ''
		begin
			--nothing to log, not point logging blank info message as the action status will show OK.
			return 
		end
	else
		begin
			set @error = @error + ' (@queue_item_id: ' + convert(varchar(100),@queue_item_id) + ')'
			exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = '6DC68414-915F-4B52-91B6-4D0B6018243B',
					@process_message = @error,
					@process_message_type = @exec_status
		end
end
