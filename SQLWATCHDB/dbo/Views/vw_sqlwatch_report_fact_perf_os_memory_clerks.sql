CREATE VIEW [dbo].[vw_sqlwatch_report_fact_perf_os_memory_clerks] with schemabinding
as
SELECT [report_time]
      ,omc.[total_kb]
      ,omc.[allocated_kb]
      ,omc.[sql_instance]
	  ,mdc.clerk_name
	  , omc.snapshot_type_id
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, omc.snapshot_time
, omc.sqlwatch_mem_clerk_id
  FROM [dbo].[sqlwatch_logger_perf_os_memory_clerks] omc
	
	inner join [dbo].[sqlwatch_meta_memory_clerk] mdc
		on mdc.sql_instance = omc.sql_instance
		and mdc.sqlwatch_mem_clerk_id = omc.sqlwatch_mem_clerk_id

    inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = omc.sql_instance
		and sh.snapshot_time = omc.[snapshot_time]
		and sh.snapshot_type_id = omc.snapshot_type_id