CREATE VIEW [dbo].[vw_sqlwatch_report_xes_iosubsystem] with schemabinding
as
SELECT [event_time]
      ,[io_latch_timeouts]
      ,[total_long_ios]
      ,[longest_pending_request_file]
      ,[longest_pending_request_duration]
      ,[report_time] = convert(smalldatetime,[snapshot_time])
      ,[sql_instance]
  FROM [dbo].[sqlwatch_logger_xes_iosubsystem]
