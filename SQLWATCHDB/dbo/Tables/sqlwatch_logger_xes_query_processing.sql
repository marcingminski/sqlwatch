CREATE TABLE [dbo].[sqlwatch_logger_xes_query_processing]
(
	[event_time] datetime,
	[max_workers] bigint,
	[workers_created] bigint,
	[idle_workers] bigint,
	[pending_tasks] bigint,
	[unresolvable_deadlocks] int,
	[deadlocked_scheduler] int,
	[snapshot_time] datetime not null,
	[snapshot_type_id] tinyint not null default 1 ,
	[sql_instance] nvarchar(25) not null default @@SERVERNAME,
	constraint fk_logger_xe_query_processing_snapshot_header foreign key ([snapshot_time],[snapshot_type_id],[sql_instance]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id],[sql_instance]) on delete cascade  on update cascade,
	constraint [pk_logger_xe_query_processing] primary key (
		[snapshot_time], [snapshot_type_id], [sql_instance], [event_time]
		),
	constraint fk_sqlwatch_logger_xes_query_processing_server foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([sql_instance]) on delete cascade
)
go

CREATE NONCLUSTERED INDEX idx_sqlwatch_xes_query_processing_001
ON [dbo].[sqlwatch_logger_xes_query_processing] ([sql_instance])
INCLUDE ([snapshot_time],[snapshot_type_id])