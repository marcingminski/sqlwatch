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
      ,report_time
      ,xb.[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_blockers] xb
	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = xb.sql_instance
		and sh.snapshot_time = xb.[snapshot_time]
		and sh.snapshot_type_id = xb.snapshot_type_id
