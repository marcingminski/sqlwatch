CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_requests_long_requests](
	[session_id] [bigint] not null,
	sqlwatch_database_id smallint not null,
	[cpu_time] [bigint] NULL,
	[physical_reads] [bigint] NULL,
	[logical_reads] [bigint] NULL,
	[writes] [bigint] NULL,
	[spills] [bigint] NULL,
	[username] [varchar](255) NULL,
	[client_hostname] [varchar](255) NULL,
	[client_app_name] [varchar](255) NULL,
	[duration_ms] [bigint] NULL,
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_xes_long_queries_type default (7),
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_xes_long_queries_sql_instance default (@@SERVERNAME),
	--query_plan nvarchar(max),
	--sql_text varchar(max),
	start_time datetime2(3),
	request_id int,
	command nvarchar(32),
	query_hash varbinary(8),
	query_plan_hash varbinary(8),
	start_time_utc datetime2(3)

	constraint pk_logger_perf_xes_long_queries primary key nonclustered (
		[snapshot_time], [snapshot_type_id], start_time, session_id,request_id
	),

	constraint fk_logger_perf_xes_long_queries 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) 
		on delete cascade  on update cascade,

	constraint fk_sqlwatch_logger_xes_long_queries_database foreign key ([sql_instance], sqlwatch_database_id)
		references [dbo].[sqlwatch_meta_database] ([sql_instance], sqlwatch_database_id) on delete cascade	

);