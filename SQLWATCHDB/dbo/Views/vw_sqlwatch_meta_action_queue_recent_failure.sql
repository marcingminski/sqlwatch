CREATE VIEW [dbo].[vw_sqlwatch_meta_action_queue_recent_failure] with schemabinding
	AS select top 1000 
		  [sql_instance]
		, [queue_item_id]
		, [action_exec_type]
		, [time_queued]
		, [action_exec]
		, [exec_status]
		, [exec_time_start]
		, [exec_time_end]
		, [retry_count]
	from [dbo].[sqlwatch_meta_action_queue]
	where exec_status <> 'OK'
	order by queue_item_id desc
