CREATE VIEW [dbo].[vw_sqlwatch_help_action_queue_failures] with schemabinding
	AS select top 100 percent
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
