CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_query_processing] with schemabinding
as
SELECT [event_time]
      ,[max_workers]
      ,[workers_created]
      ,[idle_workers]
      ,[pending_tasks]
      ,[unresolvable_deadlocks]
      ,[deadlocked_scheduler]
      ,report_time
      ,qp.[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_query_processing] qp
  	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = qp.sql_instance
		and sh.snapshot_time = qp.[snapshot_time]
		and sh.snapshot_type_id = qp.snapshot_type_id
