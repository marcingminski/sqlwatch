CREATE VIEW [dbo].[vw_sqlwatch_report_xes_query_processing] with schemabinding
as
SELECT [event_time]
      ,[max_workers]
      ,[workers_created]
      ,[idle_workers]
      ,[pending_tasks]
      ,[unresolvable_deadlocks]
      ,[deadlocked_scheduler]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_query_processing]
