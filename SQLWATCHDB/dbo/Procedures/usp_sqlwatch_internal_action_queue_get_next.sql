CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_action_queue_get_next]
as
set xact_abort on
begin tran
	;with cte_get_message as (
		select top 1 *
		from [dbo].[sqlwatch_meta_action_queue]
		where [exec_status] is null
			--try reprocess previously faild items every 5 minutes
			or ([exec_status] = 'RETRYING' and datediff(minute,isnull([exec_time_end],'1970-01-01'),sysdatetime()) > 5)
		order by [time_queued]
	)
	update cte_get_message
		set [exec_status] = 'PROCESSING',
			[exec_time_start] = sysdatetime()
			--[action_exec] = replace(
			--					replace([action_exec],'{ACTION_EXEC_TIME}',convert(varchar(23),getdate(),121))
			--					,'{ACTION_EXEC_UTCTIME}',convert(varchar(23),getutcdate(),121)
			--					)
		output 
			  deleted.[action_exec], deleted.[action_exec_type], deleted.[queue_item_id]
commit tran