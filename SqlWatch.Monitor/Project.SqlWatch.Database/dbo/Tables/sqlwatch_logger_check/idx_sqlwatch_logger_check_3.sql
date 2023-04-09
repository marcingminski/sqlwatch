create nonclustered index idx_sqlwatch_logger_check_3
	on [dbo].[sqlwatch_logger_check] ([check_id])
	include ([sql_instance],[snapshot_time],[snapshot_type_id],[check_value])
	with (data_compression=page)