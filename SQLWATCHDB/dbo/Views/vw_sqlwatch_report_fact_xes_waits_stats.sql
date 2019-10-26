CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_waits_stats] with schemabinding
as

SELECT d.[event_time]
      ,d.[session_id]
      ,mws.wait_type
      ,d.[duration]
      ,d.[signal_duration]
      ,d.[wait_resource]
      ,d.[sql_text]
      , h.report_time
      ,d.[activity_id]
      ,d.[activity_sequence]
      ,d.[username]
      ,d.[database_name]
      ,d.[client_hostname]
      ,d.[client_app_name]
      ,d.[activity_id_xfer]
      ,d.[activity_seqeuence_xfer]
      ,d.[event_name]
      ,d.[sql_instance]
      ,d.[sqlwatch_activity_id]
  FROM [dbo].[sqlwatch_logger_xes_waits_stats] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
	inner join [dbo].[sqlwatch_meta_wait_stats] mws
		on mws.sql_instance = d.sql_instance
		and mws.wait_type_id = d.wait_type_id