CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_schedulers] with schemabinding
as
SELECT report_time
      ,[scheduler_count]
      ,[idle_scheduler_count]
      ,[current_tasks_count]
      ,[runnable_tasks_count]
      ,[preemptive_switches_count]
      ,[context_switches_count]
      ,[idle_switches_count]
      ,[current_workers_count]
      ,[active_workers_count]
      ,[work_queue_count]
      ,[pending_disk_io_count]
      ,[load_factor]
      ,[yield_count]
      ,[failed_to_create_worker]
      ,[total_cpu_usage_ms]
      ,[total_scheduler_delay_ms]
      ,d.[sql_instance]
	  ,d.snapshot_type_id
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
  FROM [dbo].[sqlwatch_logger_perf_os_schedulers] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
