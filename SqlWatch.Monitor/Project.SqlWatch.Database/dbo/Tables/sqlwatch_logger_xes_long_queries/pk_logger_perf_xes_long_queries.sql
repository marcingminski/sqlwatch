ALTER TABLE [dbo].[sqlwatch_logger_xes_long_queries]
	ADD CONSTRAINT [pk_logger_perf_xes_long_queries]
	PRIMARY KEY ([snapshot_time], [snapshot_type_id], [event_time], [event_name],[session_id], plan_handle)
	WITH (DATA_COMPRESSION=PAGE)
