CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] with schemabinding
as

select m.[object_name], m.[counter_name], [instance_name], [cntr_value_raw]=[cntr_value], report_time, d.[sql_instance], [cntr_value_calculated]
	--, pcp.desired_value_desc, pcp.desired_value, pcp.description
	, [aggregation_interval_minutes] = 1
	, d.snapshot_type_id
	, d.snapshot_time
	, d.performance_counter_id
from [dbo].[sqlwatch_logger_perf_os_performance_counters] d
  	
	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_performance_counter] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id


	where m.cntr_type <> 1073939712

	/* aggregated data. we are going to have to specify aggregataion level for every select */
	union all

	/* TO DO this table needs actual report_time of utc offset otherwise we wont be able to use it */
	select m.[object_name], m.[counter_name], [instance_name], [cntr_value]=null
	, [report_time]
	, d.[sql_instance]
	, [cntr_value_calculated_avg]
	, [trend_interval_minutes] 
	, snapshot_type_id = 1
	, snapshot_time = convert(datetime2(0),snapshot_time_offset)
	, d.performance_counter_id
	from [dbo].[sqlwatch_trend_perf_os_performance_counters] d
	inner join [dbo].[sqlwatch_meta_performance_counter] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id

 