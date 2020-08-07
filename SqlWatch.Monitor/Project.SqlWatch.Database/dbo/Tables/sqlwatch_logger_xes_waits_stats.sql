CREATE TABLE [dbo].[sqlwatch_logger_xes_waits_stats]
(
	[event_time] datetime,
	[session_id] int,
	[wait_type_id] smallint,  --this can be null, cannot enforce FK relationship but we can at least save some storage by keeping ID rather than the actual wait string,
	[duration] bigint,
	[signal_duration] bigint,
	[wait_resource] varchar(255),
	[sql_text] varchar(max),
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null constraint df_sqlwatch_logger_xes_waits_stats_type default (8) ,
	[activity_id] uniqueidentifier null constraint df_sqlwatch_logger_xes_waits_stats_activity_id default (newid()),
	[activity_sequence] int null default 0,
	[username] varchar(255) null,
	[database_name] varchar(255) null,
	[client_hostname] varchar(255) null,
	[client_app_name] varchar(255) null,
	[activity_id_xfer] uniqueidentifier null,
	[activity_seqeuence_xfer] int null,
	[event_name] [varchar](255) null,
	[sql_instance] varchar(32) not null constraint df_sqlwatch_logger_xes_waits_stats_sql_isntance default (@@SERVERNAME),
	[sqlwatch_activity_id] bigint identity(1,1),
	constraint fk_logger_xes_waits_snapshot_header foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) on delete cascade on update cascade,
	constraint [pk_logger_xes_waits] primary key (
		[snapshot_time],[sql_instance], [sqlwatch_activity_id], [snapshot_type_id]
		),
	constraint fk_sqlwatch_logger_xes_waits_stats_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) on delete cascade
)
go
--CREATE NONCLUSTERED INDEX idx_sqlwatch_xes_wait_stats_001
--ON [dbo].[sqlwatch_logger_xes_waits_stats] ([sql_instance])
--INCLUDE ([snapshot_time],[snapshot_type_id])