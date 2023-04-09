CREATE TABLE [dbo].[sqlwatch_logger_xes_query_problems]
(
	[event_id] int identity(1,1) not null,
	[event_time] [datetime] not null,
	[event_name] [varchar](255) not null,
	[database_name] [varchar](255) NULL,
	[username] [varchar](255) NULL,
	[client_hostname] [varchar](255) NULL,
	[client_app_name] [varchar](255) NULL,

	[snapshot_time] datetime2(0) not null,
	[snapshot_type_id] tinyint not null ,
	[sql_instance] varchar(32) not null ,
	[problem_details] xml,
	[event_hash] varbinary(20),
	[occurence] real,
	
	constraint fk_sqlwatch_logger_xes_query_problems_header 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) 
		on delete cascade  on update cascade,

	constraint fk_sqlwatch_logger_xes_query_problems_servername 
		foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) 
		on delete cascade
)
go
