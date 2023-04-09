CREATE TABLE [dbo].[sqlwatch_logger_xes_blockers]
(
	[monitor_loop] bigint not null,
	[event_time] datetime not null,
	
	[blocked_ecid] int not null,
	[blocked_spid] int not null,
	[blocking_ecid] int not null,
	[blocking_spid] int not null,
	
	[report_xml] xml not null,

	[lockMode] nvarchar(128),
	[blocked_clientapp] nvarchar(128),
	[blocked_currentdbname] nvarchar(128),
	[blocked_hostname] nvarchar(128),
	[blocked_loginname] nvarchar(128),
	[blocked_inputbuff] nvarchar(max),

	[blocking_clientapp] nvarchar(128),
	[blocking_currentdbname] nvarchar(128),
	[blocking_hostname] nvarchar(128),
	[blocking_loginname] nvarchar(128),
	[blocking_inputbuff] varchar(max),

	[blocking_duration_ms] real,

	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null,
	[sql_instance] varchar(32) not null,
	
	constraint fk_logger_perf_xes_blockers 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) 
		on delete cascade  on update cascade,
	
	constraint fk_sqlwatch_logger_xes_blockers_server 
		foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) 
		on delete cascade
)
go

