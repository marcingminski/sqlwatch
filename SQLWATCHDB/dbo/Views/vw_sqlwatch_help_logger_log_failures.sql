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
      ,[SQL_ERROR]
  FROM [dbo].[sqlwatch_app_log]
  where [process_message_type] = 'ERROR'