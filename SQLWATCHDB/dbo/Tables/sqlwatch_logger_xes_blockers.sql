CREATE TABLE [dbo].[sqlwatch_logger_xes_blockers]
(
	[attach_activity_id] uniqueidentifier not null,
	[attach_activity_sequence] int not null,
	[blocking_start_time] datetime not null,
	[blocking_end_time] datetime not null,
	[blocked_ecid] int,
	[blocked_spid] int,
	[blocked_sql] nvarchar(max),
	[database_name] sysname,
	[lock_mode] varchar(128),
	[blocking_ecid] int,
	[blocking_spid] int,
	[blocking_sql] nvarchar(max),
	[blocking_duration_ms] int,
	[blocking_client_app_name] sysname,
	[blocking_client_hostname] sysname,
	[report_xml] xml,
	[snapshot_time] datetime2(0),
	[snapshot_type_id] tinyint,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_xes_blockers_sql_instance default (@@SERVERNAME),
	constraint fk_logger_perf_xes_blockers foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade  on update cascade,
	constraint pk_logger_perf_xes_blockers primary key clustered (
		[snapshot_time], [snapshot_type_id], [attach_activity_id], [attach_activity_sequence], [sql_instance]
	),
	constraint fk_sqlwatch_logger_xes_blockers_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
