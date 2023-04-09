create nonclustered index idx_sqlwatch_logger_snapshot_header_type_id
	on [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_type_id])
	with (data_compression=page)