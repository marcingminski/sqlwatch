CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_app_log_add_message]
	@process_name			nvarchar(max) = null,
	@process_stage			nvarchar(max),
	@process_message		nvarchar(max),
	@process_message_type	nvarchar(7),
	@proc_id				int = null,
	@message_payload		xml = null
as
begin
	set nocount on;

	begin try	

		declare @snapshot_time datetime2(0),
				@logginglevel int,
				@messagelevel int
				;

		set @logginglevel = dbo.ufn_sqlwatch_get_config_value(7, null)

		/*
			0 - Off - Output no tracing and debugging messages.
			1 - Error - Output error-handling messages.
			2 - Warning - Output warnings and error-handling messages.
			3 - Info - Output informational messages, warnings, and error-handling messages.
			4 - Verbose	- Output all debugging and tracing messages
		*/

		select @messagelevel = case @process_message_type
			when 'ERROR' then 1
			when 'WARNING' then 2
			when 'INFO' then 3
			when 'VERBOSE' then 4
			when 'DEBUG' then 4 -- common alias for VERBOSE
		else 5 end

		if	@messagelevel > @logginglevel
			begin
				return;
			end

		if @process_name is null and @proc_id is not null
			begin
				set @process_name = OBJECT_NAME(@proc_id);
			end

		insert into dbo.[sqlwatch_app_log] (
			 [process_name]			
			,[process_stage]			
			,[process_message]		
			,[process_message_type]	
			,[spid]					
			,[process_login]			
			,[process_user]			
			,[ERROR_NUMBER]
			,[ERROR_SEVERITY]
			,[ERROR_STATE]
			,[ERROR_PROCEDURE]
			,[ERROR_LINE]
			,[ERROR_MESSAGE]
			,message_payload
		)
		values (
			@process_name, @process_stage, @process_message, @process_message_type,
			@@SPID, SYSTEM_USER, USER
				, case when @process_message_type <> 'INFO' then ERROR_NUMBER() else null end
				, case when @process_message_type <> 'INFO' then ERROR_SEVERITY() else null end
				, case when @process_message_type <> 'INFO' then ERROR_STATE() else null end
				, case when @process_message_type <> 'INFO' then ERROR_PROCEDURE() else null end
				, case when @process_message_type <> 'INFO' then ERROR_LINE() else null end
				, case when @process_message_type <> 'INFO' then ERROR_MESSAGE() else null end
				, @message_payload
		)

	end try
	begin catch
		--fatal error in the error loggin procedure
		declare @message nvarchar(max);
		set @message = (select case when ERROR_MESSAGE() is not null then (
		select 'ERROR_NUMBER=' + isnull(convert(nvarchar(max),ERROR_NUMBER()),'') + char(10) + 
'ERROR_SEVERITY=' + isnull(convert(nvarchar(max),ERROR_SEVERITY()),'') + char(10) + 
'ERROR_STATE=' + isnull(convert(nvarchar(max),ERROR_STATE()),'') + char(10) + 
'ERROR_PROCEDURE=''' + isnull(convert(nvarchar(max),ERROR_PROCEDURE()),'') + '''' + char(10) + 
'ERROR_LINE=' + isnull(convert(nvarchar(max),ERROR_LINE()),'') + char(10) + 
'ERROR_MESSAGE=''' + isnull(convert(nvarchar(max),ERROR_MESSAGE()),'') + ''''
		) else null end);
		raiserror (@message,16,1);
		print @message;
	end catch
end;