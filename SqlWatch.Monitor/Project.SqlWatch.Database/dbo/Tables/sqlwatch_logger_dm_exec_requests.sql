CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_requests]
(
	[session_id] [smallint] NOT NULL,
	[start_time] [datetime] NOT NULL,
	[status] [nvarchar](30) NOT NULL,
	[command] [nvarchar](32) NOT NULL,
	[sql_handle] [varbinary](64) NULL,
	[plan_handle] [varbinary](64) NULL,
	[database_name] [sysname] NOT NULL,
	[blocking_session_id] [smallint] NULL,
	[wait_type] [nvarchar](60) NULL,
	[wait_time] [int] NOT NULL,
	[text] [nvarchar](max) NULL,
	[program_name] [nvarchar](128) NULL,
	[client_interface_name] [nvarchar](32) NULL,
	[host_name] [nvarchar](128) NULL,
	[login_name] [nvarchar](128) NULL,
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	sql_instance varchar(32) not null,

	constraint pk_sqlwatch_logger_dm_exec_requests 
		primary key clustered ([session_id], [start_time], snapshot_time, sql_instance, snapshot_type_id),

	constraint fk_sqlwatch_logger_dm_exec_requests_snapshot_header 
		foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) 
		on delete cascade on update cascade
)
