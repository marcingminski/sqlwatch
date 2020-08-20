CREATE VIEW [dbo].[vw_sqlwatch_report_fact_check]
	AS 

select 
	  [d].[sql_instance]
	, [d].[snapshot_time]
	, [d].[check_id]
	, c.check_name
	, [d].[check_value]
	, [d].[check_status]
	, [d].[check_exec_time_ms]
	, h.report_time
	, [d].status_change
	, d.snapshot_type_id
	, c.check_description
from dbo.sqlwatch_logger_check d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

	inner join [dbo].[sqlwatch_meta_check] c
		on c.sql_instance = d.sql_instance
		and c.check_id = d.check_id