CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_memory_clerks] with schemabinding
as
SELECT [report_time] = convert(smalldatetime,omc.[snapshot_time])
      ,omc.[total_kb]
      ,omc.[allocated_kb]
      ,omc.[total_kb_all_clerks]
      ,omc.[memory_available]
      ,omc.[sql_instance]
	  ,mdc.clerk_name
  FROM [dbo].[sqlwatch_logger_perf_os_memory_clerks] omc
	
	inner join [dbo].[sqlwatch_meta_memory_clerk] mdc
		on mdc.sql_instance = omc.sql_instance
		and mdc.sqlwatch_mem_clerk_id = omc.sqlwatch_mem_clerk_id