CREATE TABLE [dbo].[logger_perf_xes_waits]
(
	[event_time] datetime,
	[session_id] int,
	[wait_type] varchar(255),
	[duration] bigint,
	[signal_duration] bigint,
	[wait_resource] varchar(255),
	[sql_text] varchar(max),
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 8 ,
	[activity_id] uniqueidentifier not null default newid(),
	[activity_sequence] int not null default 0,
	[username] varchar(255) null,
	[database_name] varchar(255) null,
	[client_hostname] varchar(255) null,
	[client_app_name] varchar(255) null,
	[activity_id_xfer] uniqueidentifier null,
	[activity_seqeuence_xfer] int null,
	[event_name] [varchar](255) null,
	constraint fk_logger_xes_waits_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sql_perf_mon_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade on update cascade,
	constraint [pk_logger_xes_waits] primary key (
		[snapshot_time] asc, [activity_id], [activity_sequence] 
		)
)
