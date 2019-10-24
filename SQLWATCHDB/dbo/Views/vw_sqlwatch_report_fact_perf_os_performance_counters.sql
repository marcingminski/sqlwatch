CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] with schemabinding
as

select [performance_counter_id], [instance_name], [cntr_value], [base_cntr_value], report_time, d.[sql_instance], [cntr_value_calculated] 
from [dbo].[sqlwatch_logger_perf_os_performance_counters] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

 