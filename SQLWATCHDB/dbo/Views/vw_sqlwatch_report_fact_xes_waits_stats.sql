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
	  ,wait_category = isnull(mws.wait_category,'Other')
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_xes_waits_stats] d

  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[vw_sqlwatch_meta_wait_stats_category] mws
		on mws.sql_instance = d.sql_instance
		and mws.wait_type_id = d.wait_type_id

	-- NO LONGER NEEDED:
	--left join [dbo].[sqlwatch_config_wait_stats] cw
	--	on cw.wait_type = mws.wait_type