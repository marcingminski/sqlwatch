CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_action_queue_update]
	@queue_item_id bigint,
	@exec_status varchar(50) = null,
	@error nvarchar(max) = null
as
begin
	declare @queue_retetion_days tinyint = 1

	set @exec_status = case 
		when @exec_status is null and isnull(@error,'') <> '' then 'FAILED'
		when @exec_status is null and isnull(@error,'') = '' then 'OK'
	else 'UNKNOWN' end

	update [dbo].[sqlwatch_meta_action_queue] 
		set [exec_status] = @exec_status 
	where queue_item_id = @queue_item_id

	if @exec_status <> 'OK'
		begin
			exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = '6DC68414-915F-4B52-91B6-4D0B6018243B',
					@process_message = @error,
					@process_message_type = @exec_status
		end
end
