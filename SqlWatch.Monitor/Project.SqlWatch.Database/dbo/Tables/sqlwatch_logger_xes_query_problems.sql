CREATE TABLE [dbo].[sqlwatch_logger_xes_query_problems]
(
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
	[event_hashbytes] varbinary(20),
	[occurence] real,

	constraint pk_sqlwatch_logger_xes_query_problems 
		--although the hash is done on the entire event so will take time and name into account.
		--I am going to make these fields part PK for improvement performance when reading data. I may change it later depending on performance
		primary key nonclustered ([snapshot_time], [snapshot_type_id], [event_time], [event_name], [event_hashbytes]),
	
	constraint fk_sqlwatch_logger_xes_query_problems_header 
		foreign key ([snapshot_time],[sql_instance],[snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[sql_instance],[snapshot_type_id]) 
		on delete cascade  on update cascade,

	constraint fk_sqlwatch_logger_xes_query_problems_servername 
		foreign key ([sql_instance])
		references [dbo].[sqlwatch_meta_server] ([servername]) 
		on delete cascade
)
