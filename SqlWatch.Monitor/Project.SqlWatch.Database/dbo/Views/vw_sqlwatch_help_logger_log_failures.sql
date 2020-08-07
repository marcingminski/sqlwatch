CREATE VIEW [dbo].[vw_sqlwatch_help_logger_log_failures] with schemabinding
as
SELECT 
		 [event_sequence]
		,[sql_instance]
		,[event_time]
		,[process_name]
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
  FROM [dbo].[sqlwatch_app_log]
  where [process_message_type] = 'ERROR'