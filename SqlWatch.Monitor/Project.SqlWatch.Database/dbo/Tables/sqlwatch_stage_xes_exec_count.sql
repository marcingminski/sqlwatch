CREATE TABLE [dbo].[sqlwatch_stage_xes_exec_count]
(
	session_name nvarchar (64) not null,
	event_session_address varbinary(8),
	execution_count bigint not null,
	last_event_time datetime2(0) null,
	event_session_file_offset bigint,
	event_session_file nvarchar(260),
	last_retrieved_from_file_time datetime2(0),
	last_retrieved_from_file_rowcount int,
	last_file_change datetime2(0),

	constraint pk_sqlwatch_stage_xes_exec_count 
		primary key clustered (
			session_name
		)
)
