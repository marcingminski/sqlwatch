CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] with schemabinding
as

select 
	m.[object_name]
	, m.[counter_name]
	, [instance_name]
	, [cntr_value_raw]=[cntr_value]
	, report_time
	, d.[sql_instance]
	, [cntr_value_calculated]
	, [aggregation_interval_minutes] = 0
	, d.snapshot_type_id
	, d.snapshot_time
	, d.performance_counter_id
	, is_trend = 0
from [dbo].[sqlwatch_logger_dm_os_performance_counters] d
  	
	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_dm_os_performance_counters] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id

	where m.cntr_type <> 1073939712

union all

select 
	m.[object_name]
	, m.[counter_name]
	, [instance_name]
	, [cntr_value_raw]=null
	, report_time
	, d.[sql_instance]
	, [cntr_value_calculated] = [cntr_value_calculated_avg]
	, [aggregation_interval_minutes] = datediff(minute,[original_snapshot_time_from],[original_snapshot_time_to])
	, d.snapshot_type_id
	, d.snapshot_time
	, d.performance_counter_id
	, is_trend = 1
from [dbo].[sqlwatch_trend_logger_dm_os_performance_counters] d
  	
	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_dm_os_performance_counters] m
		on m.sql_instance = d.sql_instance
		and m.performance_counter_id = d.performance_counter_id

	where m.cntr_type <> 1073939712