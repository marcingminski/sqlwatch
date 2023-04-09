CREATE NONCLUSTERED INDEX idx_sqlwatch_logger_xes_blockers_1
	ON [dbo].[sqlwatch_logger_xes_blockers] ([monitor_loop],[blocking_ecid],[blocking_spid])
	WITH (DATA_COMPRESSION=PAGE)