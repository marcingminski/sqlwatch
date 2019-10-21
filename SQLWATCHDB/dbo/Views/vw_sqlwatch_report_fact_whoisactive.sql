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
      ,wi.[sql_instance]
  FROM [dbo].[sqlwatch_logger_whoisactive] wi
          inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = wi.sql_instance
		and sh.snapshot_time = wi.[snapshot_time]
		and sh.snapshot_type_id = wi.snapshot_type_id
