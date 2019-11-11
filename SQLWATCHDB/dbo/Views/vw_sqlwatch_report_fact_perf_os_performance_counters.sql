CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] with schemabinding
as

select m.[object_name], m.[counter_name], [instance_name], [cntr_value_raw]=[cntr_value], report_time, d.[sql_instance], [cntr_value_calculated]
	--, pcp.desired_value_desc, pcp.desired_value, pcp.description
	, [aggregation_interval_minutes] = 1
from [dbo].[sqlwatch_logger_perf_os_performance_counters] d
  	
	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_performance_counter] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id

	--left join [dbo].[sqlwatch_config_performance_counters_poster] pcp
	--	on pcp.sql_instance = d.sql_instance
	--	and pcp.object_name = m.object_name
	--	and pcp.counter_name = m.counter_name

	where m.cntr_type <> 1073939712


	/* aggregated data. we are going to have to specify aggregataion level for every select */
	union all

	select m.[object_name], m.[counter_name], [instance_name], [cntr_value]=null
	, report_time=[snapshot_time]
	, d.[sql_instance]
	, [cntr_value_calculated]
	, [trend_interval_minutes] 
	from [dbo].[sqlwatch_trend_perf_os_performance_counters] d
	inner join [dbo].[sqlwatch_meta_performance_counter] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id

 