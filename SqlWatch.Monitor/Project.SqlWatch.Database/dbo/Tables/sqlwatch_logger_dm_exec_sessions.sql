CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_sessions]
(
	[session_id] [smallint] NOT NULL,
	[login_time] [datetime] NOT NULL,
	[host_name] [nvarchar](128) NULL,
	[program_name] [nvarchar](128) NULL,
	[client_interface_name] [nvarchar](32) NULL,
	[login_name] [nvarchar](128) NOT NULL,
	[status] [nvarchar](30) NOT NULL,
	[cpu_time] [real] NOT NULL,
	[memory_usage] [real] NOT NULL,
	[total_scheduled_time] [real] NOT NULL,
	[total_elapsed_time] [real] NOT NULL,
	[last_request_start_time] [datetime] NOT NULL,
	[last_request_end_time] [datetime] NULL,
	[reads] [real] NOT NULL,
	[writes] [real] NOT NULL,
	[logical_reads] [real] NOT NULL,
	[database_name] [sysname] NULL,
	[snapshot_time] [datetime2](0) NOT NULL,
	[snapshot_type_id] [tinyint] NOT NULL,
	[sql_instance] [varchar](32) NOT NULL,

	constraint pk_sqlwatch_logger_dm_exec_sessions  primary key clustered
	(
		[session_id] ASC,
		[snapshot_time] ASC,
		[snapshot_type_id] ASC,
		[sql_instance] ASC
	),

	constraint [fk_sqlwatch_logger_dm_exec_sessions_snapshot_header] 
	foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
	references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [sql_instance], [snapshot_type_id])
	on update cascade
	on delete cascade
)
