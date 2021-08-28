CREATE TABLE [dbo].[sqlwatch_logger_xes_deadlocks]
(
	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null,
	[sql_instance] varchar(32) not null,
	[activity_id] varchar(60),
	[event_time] datetime2(0) not null,
	[xml_report] xml not null,

	constraint pl_sqlwatch_logger_xes_deadlocks 
		primary key clustered (event_time, [activity_id], snapshot_time, snapshot_type_id, sql_instance),

	constraint fk_sqlwatch_logger_xes_deadlocks_header
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) 
		on delete cascade  
		on update cascade,

	constraint fk_sqlwatch_logger_xes_deadlocks_server 
		foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) 
		on delete cascade

);
