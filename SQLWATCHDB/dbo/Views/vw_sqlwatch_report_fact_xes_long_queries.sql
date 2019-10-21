CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_long_queries] with schemabinding
as

SELECT [activity_id]
      ,[activity_sequence]
      ,[activity_id_xfer]
      ,[activity_seqeuence_xfer]
      ,[event_time]
      ,[event_name]
      ,[session_id]
      ,[database_name]
      ,[cpu_time]
      ,[physical_reads]
      ,[logical_reads]
      ,[writes]
      ,[spills]
      ,[offset]
      ,[offset_end]
      ,[statement]
      ,[username]
      ,[sql_text]
      ,[object_name]
      ,[client_hostname]
      ,[client_app_name]
      ,[duration_ms]
      ,[wait_type]
      ,report_time
      ,xq.[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_long_queries] xq
  	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = xq.sql_instance
		and sh.snapshot_time = xq.[snapshot_time]
		and sh.snapshot_type_id = xq.snapshot_type_id
