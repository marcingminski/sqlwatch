CREATE VIEW [dbo].[vw_sqlwatch_report_perf_os_wait_stats] with schemabinding
as
SELECT [wait_type]
      ,[waiting_tasks_count]
      ,[wait_time_ms]
      ,[max_wait_time_ms]
      ,[signal_wait_time_ms]
      ,[snapshot_time]
      ,[snapshot_type_id]
      ,ws.[sql_instance]
  FROM [dbo].[sqlwatch_logger_perf_os_wait_stats] ws
	inner join [dbo].[sqlwatch_meta_wait_stats] ms
		on ws.sql_instance = ms.sql_instance
		and ws.wait_type_id = ms.wait_type_id
