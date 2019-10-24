CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_wait_stats] with schemabinding
as
select [wait_type_id], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], report_time, d.[sql_instance]
, [waiting_tasks_count_delta], [wait_time_ms_delta], [max_wait_time_ms_delta], [signal_wait_time_ms_delta], [delta_seconds] 
from [dbo].[sqlwatch_logger_perf_os_wait_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance