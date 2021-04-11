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
from [dbo].[ufn_sqlwatch_get_blocking_chains]('1970-01-01','2099-21-31', null)
