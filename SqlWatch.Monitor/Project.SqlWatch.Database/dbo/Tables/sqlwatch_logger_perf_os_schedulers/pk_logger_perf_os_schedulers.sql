ALTER TABLE [dbo].[sqlwatch_logger_perf_os_schedulers]
	ADD CONSTRAINT [pk_logger_perf_os_schedulers]
	PRIMARY KEY ([snapshot_time] ASC, [snapshot_type_id],  [sql_instance])
	WITH (DATA_COMPRESSION=PAGE)
