CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_action_queue_get_next]
as
set xact_abort on
begin tran
	;with cte_get_message as (
		select top 1 *
		from [dbo].[sqlwatch_meta_action_queue]
		where [exec_status] is null
		order by [time_queued]
	)
	update cte_get_message
		set [exec_status] = 'PROCESSING'
		output deleted.[action_exec], deleted.[action_exec_type], deleted.[queue_item_id]
commit tran