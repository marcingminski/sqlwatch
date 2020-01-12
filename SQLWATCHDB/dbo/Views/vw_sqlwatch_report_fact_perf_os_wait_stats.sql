CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_wait_stats] with schemabinding
as
select report_time, d.[sql_instance], m.wait_type
, [waiting_tasks_count_delta], [wait_time_ms_delta], [max_wait_time_ms_delta], [signal_wait_time_ms_delta]
, wait_category = isnull(m.wait_category,'Other')
, report_include = convert(bit,1)
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
, d.wait_type_id
from [dbo].[sqlwatch_logger_perf_os_wait_stats] d
  	
	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
	
	inner join dbo.vw_sqlwatch_meta_wait_stats_category m
		on m.sql_instance = d.sql_instance
		and m.wait_type_id = d.wait_type_id
	
	-- NO LONGER NEEDED:
	--left join [dbo].[sqlwatch_config_wait_stats] cw
	--	on cw.wait_type = m.wait_type