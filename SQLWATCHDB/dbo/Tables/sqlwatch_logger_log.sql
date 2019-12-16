CREATE TABLE [dbo].[sqlwatch_logger_log](
	[event_sequence]		int	identity(1,1),
	[snapshot_time]			datetime2(0) not null,
	[snapshot_type_id]		tinyint not null ,
	[sql_instance]			varchar(32) not null constraint df_sqlwatch_logger_sql_instance default @@SERVERNAME,
	[event_time]			time constraint df_sqlwatch_logger_log_time default SYSDATETIME(),
	[process_name]			nvarchar(512),
	[process_stage]			nvarchar(max),
	[process_message]		nvarchar(max),
	[process_message_type]	varchar(50),
	[spid]					int,
	[process_login]			nvarchar(512),
	[process_user]			nvarchar(512),
	[SQL_ERROR]				xml,
	
	constraint pk_sqlwatch_logger_log primary key clustered (
		[event_sequence], [snapshot_time], [sql_instance], [snapshot_type_id]
	),
	constraint fk_sqlwatch_logger_log_header foreign key ([snapshot_time], [sql_instance], [snapshot_type_id])
		references [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [sql_instance], [snapshot_type_id]) on delete cascade,

	constraint chk_sqlwatch_logger_log_message_type check (([process_message_type] = 'INFO' or [process_message_type] = 'WARNING' or [process_message_type] = 'ERROR'))
)
go
