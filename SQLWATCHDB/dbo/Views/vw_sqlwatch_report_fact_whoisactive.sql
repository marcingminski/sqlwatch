CREATE VIEW [dbo].[vw_sqlwatch_report_fact_whoisactive] with schemabinding
as
SELECT [sqlwatch_whoisactive_record_id]
      ,report_time
      ,[start_time]
      ,[session_id]
      ,[status]
      ,[percent_complete]
      ,[host_name]
      ,[database_name]
      ,[program_name]
      ,[sql_text]
      ,[sql_command]
      ,[login_name]
      ,[open_tran_count]
      ,[wait_info]
      ,[blocking_session_id]
      ,[blocked_session_count]
      ,[CPU]
      ,[used_memory]
      ,[tempdb_current]
      ,[tempdb_allocations]
      ,[reads]
      ,[writes]
      ,[physical_reads]
      ,[login_time]
      ,d.[sql_instance]
  FROM [dbo].[sqlwatch_logger_whoisactive] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
