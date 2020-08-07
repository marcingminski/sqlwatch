CREATE TABLE [dbo].[sqlwatch_app_log](
	[event_sequence]		bigint	identity(1,1),
	[sql_instance]			varchar(32) not null constraint df_sqlwatch_logger_sql_instance default @@SERVERNAME,
	[event_time]			datetime2(7) constraint df_sqlwatch_logger_log_time default SYSDATETIME(),
	[process_name]			nvarchar(512),
	[process_stage]			nvarchar(max),
	[process_message]		nvarchar(max),
	[process_message_type]	varchar(50),
	[spid]					int,
	[process_login]			nvarchar(512),
	[process_user]			nvarchar(512),
	[ERROR_NUMBER]			int,
	[ERROR_SEVERITY]		int,
	[ERROR_STATE]			int,
	[ERROR_PROCEDURE]		nvarchar(max),
	[ERROR_LINE]			int,
	[ERROR_MESSAGE]			nvarchar(max),
	
	constraint pk_sqlwatch_sys_log primary key clustered (
		[event_sequence], [sql_instance]
	),
	constraint fk_sqlwatch_sys_log foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade,
	constraint chk_sqlwatch_logger_log_message_type check (([process_message_type] = 'INFO' or [process_message_type] = 'WARNING' or [process_message_type] = 'ERROR'))
)
go


CREATE NONCLUSTERED INDEX idx_sqlwatch_logger_log_message_type
	ON [dbo].[sqlwatch_app_log] ([process_message_type])
