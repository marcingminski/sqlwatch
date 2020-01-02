CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_iosubsystem] with schemabinding
as
SELECT [event_time]
      ,[io_latch_timeouts]
      ,[total_long_ios]
      ,[longest_pending_request_file]
      ,[longest_pending_request_duration]
      ,report_time
      ,d.[sql_instance]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_xes_iosubsystem] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance