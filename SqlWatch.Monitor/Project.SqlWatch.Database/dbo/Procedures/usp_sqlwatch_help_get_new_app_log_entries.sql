CREATE PROCEDURE [dbo].[usp_sqlwatch_help_get_new_app_log_entries]
	@process_message_type nvarchar(7) = null
as
begin
	declare @event_sequence int;

	select @event_sequence = max(event_sequence)
	from dbo.sqlwatch_stage_app_log_last_read_event;

	declare @app_log table (
		[event_sequence] [bigint]  NULL,
		[sql_instance] [varchar](32)  NULL,
		[event_time] [datetime2](7) NULL,
		[process_name] [nvarchar](512) NULL,
		[process_stage] [nvarchar](max) NULL,
		[process_message] [nvarchar](max) NULL,
		[process_message_type] [varchar](7) NULL,
		[spid] [int] NULL,
		[process_login] [nvarchar](512) NULL,
		[process_user] [nvarchar](512) NULL,
		[ERROR_NUMBER] [int] NULL,
		[ERROR_SEVERITY] [int] NULL,
		[ERROR_STATE] [int] NULL,
		[ERROR_PROCEDURE] [nvarchar](max) NULL,
		[ERROR_LINE] [int] NULL,
		[ERROR_MESSAGE] [nvarchar](max) NULL,
		[message_payload] [xml] NULL
	);

	if @event_sequence is not null
		begin
			insert into @app_log
			select * 
			from dbo.sqlwatch_app_log
			where event_sequence > @event_sequence;
		end
	else
		begin
			insert into @app_log
			select * 
			from dbo.sqlwatch_app_log
		end;

	select @event_sequence = max(event_sequence)
	from @app_log;

	if @event_sequence is not null
		begin
			truncate table dbo.sqlwatch_stage_app_log_last_read_event;

			insert into dbo.sqlwatch_stage_app_log_last_read_event (event_sequence)
			values ( @event_sequence );
		end;

	select *
	from @app_log
	where process_message_type = isnull(@process_message_type,process_message_type)
	order by event_sequence desc;
end;