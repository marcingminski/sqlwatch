CREATE VIEW [dbo].[vw_sqlwatch_report_dim_check] with schemabinding
	AS 
	select ma.sql_instance, ma.check_id, ma.[check_name], ma.last_check_date, ma.last_check_value, ma.last_check_status, ma.[last_status_change_date]
		, ma.check_description
		, avg_check_exec_time_ms = convert(decimal(10,2),t.check_exec_time_ms)
		, max_check_exec_time_ms = convert(decimal(10,2),t.check_exec_time_ms_max)
		, min_check_exec_time_ms = convert(decimal(10,2),t.check_exec_time_ms_min)

		, t.total_checks_executed
		, ma.check_enabled
		, ma.target_sql_instance
	from [dbo].[sqlwatch_meta_check] ma

	--get average exec time for each check
	left join (
		select sql_instance, check_id
			, check_exec_time_ms=avg(check_exec_time_ms)
			, total_checks_executed=count(check_exec_time_ms)
			, check_exec_time_ms_max=max(check_exec_time_ms)
			, check_exec_time_ms_min=min(check_exec_time_ms)
		from [dbo].[sqlwatch_logger_check]
		group by sql_instance, check_id
	) t
	on t.sql_instance = ma.sql_instance
	and t.check_id = ma.check_id;