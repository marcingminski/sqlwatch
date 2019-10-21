CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_wait_stats] with schemabinding
as
select [wait_type_id], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], report_time, ws.[sql_instance]
, [waiting_tasks_count_delta], [wait_time_ms_delta], [max_wait_time_ms_delta], [signal_wait_time_ms_delta], [delta_seconds] 
from [dbo].[sqlwatch_logger_perf_os_wait_stats] ws
        inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = ws.sql_instance
		and sh.snapshot_time = ws.[snapshot_time]
		and sh.snapshot_type_id = ws.snapshot_type_id