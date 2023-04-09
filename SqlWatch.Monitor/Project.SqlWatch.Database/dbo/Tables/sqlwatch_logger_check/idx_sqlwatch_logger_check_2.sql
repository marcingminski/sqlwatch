create nonclustered index idx_sqlwatch_logger_check_2
	on [dbo].[sqlwatch_logger_check] ([sql_instance],[check_id])
	include ([snapshot_time],[snapshot_type_id])
	with (data_compression=page)