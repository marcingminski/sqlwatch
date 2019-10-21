CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] with schemabinding
as

select [performance_counter_id], [instance_name], [cntr_value], [base_cntr_value], report_time, pc.[sql_instance], [cntr_value_calculated] 
from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
    inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = pc.sql_instance
		and sh.snapshot_time = pc.[snapshot_time]
		and sh.snapshot_type_id = pc.snapshot_type_id

 