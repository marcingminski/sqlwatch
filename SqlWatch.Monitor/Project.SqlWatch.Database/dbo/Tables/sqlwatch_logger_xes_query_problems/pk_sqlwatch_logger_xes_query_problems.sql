ALTER TABLE [dbo].[sqlwatch_logger_xes_query_problems]
	--although the hash is done on the entire event so will take time and name into account.
	--I am going to make these fields part PK for improvement performance when reading data. I may change it later depending on performance

	--actually, this will fragment the index as hell. it needs a better design
	ADD CONSTRAINT [pk_sqlwatch_logger_xes_query_problems]
	PRIMARY KEY nonclustered ([snapshot_time], [sql_instance], [snapshot_type_id], [event_id])
	with (data_compression=page)
