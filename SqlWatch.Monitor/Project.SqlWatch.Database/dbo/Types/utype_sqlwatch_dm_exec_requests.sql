CREATE TYPE [dbo].[utype_sqlwatch_dm_exec_requests] AS TABLE
(
	request_id bigint,
	[session_id] [bigint] not null,
	start_time datetime,
	[cpu_time] [bigint] NULL,
	[physical_reads] [bigint] NULL,
	[logical_reads] [bigint] NULL,
	[writes] [bigint] NULL,
	[spills] [bigint] NULL,
	[duration_ms] [bigint] NULL,
	last_captured datetime,
	total_wait_time bigint,
	waits varchar(max),
	granted_query_memory bigint,
	query_hash binary(8),
	query_plan_hash binary(8),
	plan_handle varbinary(64),
	sql_handle varbinary(64),
	statement_start_offset int,
	statement_end_offset int,
	last_wait_type nvarchar(60)
)