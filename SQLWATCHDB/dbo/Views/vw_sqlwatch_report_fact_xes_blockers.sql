CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_blockers] with schemabinding
as

SELECT [attach_activity_id]
      ,[attach_activity_sequence]
      ,[blocking_start_time]
      ,[blocking_end_time]
      ,[blocked_ecid]
      ,[blocked_spid]
      ,[blocked_sql]
      ,[database_name]
      ,[lock_mode]
      ,[blocking_ecid]
      ,[blocking_spid]
      ,[blocking_sql]
      ,[blocking_duration_ms]
      ,[blocking_client_app_name]
      ,[blocking_client_hostname]
      ,[report_xml]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_blockers]
