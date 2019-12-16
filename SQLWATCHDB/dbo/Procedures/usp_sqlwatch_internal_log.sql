CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_log]
	@process_name			nvarchar(max) = null,
	@process_stage			nvarchar(max),
	@process_message		nvarchar(max),
	@process_message_type	nvarchar(max),
	@proc_id				int = null
as
/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_internal_log

 Description:
	Log ERRORS from the catch block into a table.
	All errors are being returned back to the console via print anyway so logging to table is only for convinience.
	Also keep in mind that any explicit rollbacks will also rollback the inert into the error log, for this to survive,
	the data must have been inserted into table viarable as they survive rollbacks. 
	Not all procedures are enabled to call this logger upon failure. 

 Parameters
	@snapshot_time			-	OPTIONAL. Can be passed from calling proc to retain time correlation 
	@CALLER_PROC_ID			-	ID of the calling procedure in case of nested proc so we can identify the caller as oppose
								to just the procedure that failed
	@APP_STAGE				-	custom user message to identify step within the procedure. I usually use GUIDS
	@APP_MESSAGE			-	custom user message to explain what the problem is within the application if custom error raised

 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-12-01	- Marcin Gminski, Initial version
-------------------------------------------------------------------------------------------------------------------
*/
SET XACT_ABORT ON
SET NOCOUNT ON 

begin try		
	declare @snapshot_type_id tinyint = 21,
			@snapshot_time datetime2(0)

	if @process_name is null and @proc_id is not null
		begin
			set @process_name = OBJECT_NAME(@proc_id)
		end

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id

	insert into dbo.sqlwatch_logger_log (
		 [snapshot_time]
		,[snapshot_type_id]
		,[process_name]			
		,[process_stage]			
		,[process_message]		
		,[process_message_type]	
		,[spid]					
		,[process_login]			
		,[process_user]			
		,[SQL_ERROR]		
	)
	values (
		@snapshot_time, @snapshot_type_id, @process_name, @process_stage, @process_message, @process_message_type,
		@@SPID, SYSTEM_USER, USER, [dbo].[ufn_sqlwatch_get_error_detail_xml]()
	)

	begin
		Print '---- ' + @process_message_type + '------------------------------------' +
'Time' + convert(nvarchar(23),@snapshot_time,121) + 
'Process Name: ' + @process_name +
'Stage: ' + @process_stage + 
'Message: ' + @process_message + 
'Message Type' + @process_message_type + 
'Error: ' + [dbo].[ufn_sqlwatch_get_error_detail_text] ()
	end
end try
begin catch
	--fatal error in the error loggin procedure
	declare @message nvarchar(max)
	set @message = [dbo].[ufn_sqlwatch_get_error_detail_text] ()
	raiserror (@message,16,1)
	print @message
end catch