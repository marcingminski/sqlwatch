CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_blockers] with schemabinding
as

-- for backward compatibility only:
select 
	  [monitor_loop]
	, [event_time]
	, [blocking_tree]
	, [blocking_level]
	, [session_id]
	, [blocking_session_id]
	, [database name]
	, [lock_mode]
	, [blocking_duration_ms]
	, [appname]
	, [hostname]
	, [sql_text]
	, [report_xml]
	, [sequence]
	, sql_instance
	, snapshot_time
	, snapshot_type_id
from [dbo].[ufn_sqlwatch_get_blocking_chains]('1970-01-01','2099-12-31', null)
