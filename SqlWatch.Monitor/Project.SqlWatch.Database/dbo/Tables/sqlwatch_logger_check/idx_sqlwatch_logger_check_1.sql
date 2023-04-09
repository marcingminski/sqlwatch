create nonclustered index idx_sqlwatch_logger_check_1
	on [dbo].[sqlwatch_logger_check] ([status_change])
	include ([check_status])
	with (data_compression=page)