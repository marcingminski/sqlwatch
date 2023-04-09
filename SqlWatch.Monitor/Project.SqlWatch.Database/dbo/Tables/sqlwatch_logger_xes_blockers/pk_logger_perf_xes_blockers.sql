ALTER TABLE [dbo].[sqlwatch_logger_xes_blockers]
	ADD CONSTRAINT [pk_logger_perf_xes_blockers]
	primary key clustered ([event_time], [monitor_loop], [blocked_spid], blocked_ecid, [blocking_spid], blocking_ecid, [sql_instance], [snapshot_time], [snapshot_type_id])
	WITH (DATA_COMPRESSION=PAGE)