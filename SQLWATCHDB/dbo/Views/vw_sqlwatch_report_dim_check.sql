CREATE VIEW [dbo].[vw_sqlwatch_report_dim_check] with schemabinding
	AS 
	select ma.sql_instance, ac.check_id, ac.[check_name], ma.last_check_date, ma.last_check_value, ma.last_check_status, ma.[last_status_change_date]
		--, last_notification_sent = lt.snapshot_time
		--, total_notifications_in_last_hour = isnull(tc.trigger_count,0)
	from [dbo].[sqlwatch_meta_check] ma
	inner join [dbo].[sqlwatch_config_check] ac
		on ma.[sql_instance] = ac.[sql_instance]
		and ma.[check_id] = ac.[check_id]

	--get last time we sent a message from the trigget history
	--left join (
	--	select sql_instance, check_id, snapshot_time = max(snapshot_time)
	--	from [dbo].[sqlwatch_logger_check_action]
	--	where [action_type] <> 'NONE'
	--	group by sql_instance, check_id
	--) lt
	--	on lt.check_id = ac.check_id
	--	and lt.sql_instance = ac.sql_instance

	----get count of triggers (messages) requested in the last hour
	--left join (
	--	select sql_instance, check_id, trigger_count = count(1)
	--	from [dbo].[sqlwatch_logger_check_action]
	--	where snapshot_time > dateadd(hour,-1,getdate())
	--	and [action_type] <> 'NONE'
	--	group by check_id, sql_instance
	--) tc
	--	on tc.sql_instance = ac.sql_instance
	--	and tc.check_id = ac.check_id
