create nonclustered index idx_sqlwatch_logger_snapshot_header_report_time 
	on [dbo].[sqlwatch_logger_snapshot_header] ([report_time])
	with (data_compression=page)