ALTER TABLE [dbo].[sqlwatch_logger_perf_query_stats]
	ADD CONSTRAINT [pk_sqlwatch_logger_perf_query_stats]
	PRIMARY KEY clustered (
			  [sql_instance]
			, plan_handle
			, statement_start_offset
			, statement_end_offset
			, [snapshot_time]
			, [snapshot_type_id]
			, [creation_time]
			)
	WITH (DATA_COMPRESSION=PAGE)