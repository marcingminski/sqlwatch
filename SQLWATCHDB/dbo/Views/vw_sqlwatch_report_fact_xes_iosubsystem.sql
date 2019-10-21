CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_iosubsystem] with schemabinding
as
SELECT [event_time]
      ,[io_latch_timeouts]
      ,[total_long_ios]
      ,[longest_pending_request_file]
      ,[longest_pending_request_duration]
      ,report_time
      ,xi.[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_iosubsystem] xi
  	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = xi.sql_instance
		and sh.snapshot_time = xi.[snapshot_time]
		and sh.snapshot_type_id = xi.snapshot_type_id