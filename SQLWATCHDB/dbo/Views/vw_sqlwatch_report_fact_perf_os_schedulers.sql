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
      ,os.[sql_instance]
  FROM [dbo].[sqlwatch_logger_perf_os_schedulers] os
        inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = os.sql_instance
		and sh.snapshot_time = os.[snapshot_time]
		and sh.snapshot_type_id = os.snapshot_type_id
