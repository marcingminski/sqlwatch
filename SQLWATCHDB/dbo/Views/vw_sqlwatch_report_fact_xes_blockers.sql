CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_blockers] with schemabinding
as
--xes will log blocking chain every time it breaches the set time threshold. 
--for example, if we have a blocking monitor set to 15 seconds and a chain lasting 1 minute, 
--the xe session will record it every 15 seconds and show 4 entries. 
--we are only interesting in the most recent entry as this will have the most accurate blocking end time
with cte_blocking_chains as (
	SELECT  [attach_activity_id], [attach_activity_sequence], [blocking_start_time], [blocking_end_time], [blocked_ecid], [blocked_spid], [blocked_sql], [database_name]
	, [lock_mode], [blocking_ecid], [blocking_spid], [blocking_sql], [blocking_duration_ms], [blocking_client_app_name], [blocking_client_hostname]
	, [report_xml], [snapshot_time], [snapshot_type_id], [sql_instance]
		, blocking_chain_no = row_number() over (partition by blocking_spid, blocked_spid, convert(datetime2(0),blocking_start_time) order by blocking_duration_ms desc)
	FROM [dbo].[sqlwatch_logger_xes_blockers]
	)
select [attach_activity_id]
      ,[attach_activity_sequence]
      ,[blocking_start_time]
      ,[blocking_end_time]
      ,[blocked_ecid]
      ,[blocked_spid]
      ,[blocked_sql]
      ,[database_name]
      ,[lock_mode]
      ,[blocking_ecid]
      ,[blocking_spid]
      ,[blocking_sql]
      ,[blocking_duration_ms]
      ,[blocking_client_app_name]
      ,[blocking_client_hostname]
      ,[report_xml]
      ,report_time
      ,d.[sql_instance]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
from cte_blocking_chains d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
where blocking_chain_no = 1

--SELECT [attach_activity_id]
--      ,[attach_activity_sequence]
--      ,[blocking_start_time]
--      ,[blocking_end_time]
--      ,[blocked_ecid]
--      ,[blocked_spid]
--      ,[blocked_sql]
--      ,[database_name]
--      ,[lock_mode]
--      ,[blocking_ecid]
--      ,[blocking_spid]
--      ,[blocking_sql]
--      ,[blocking_duration_ms]
--      ,[blocking_client_app_name]
--      ,[blocking_client_hostname]
--      ,[report_xml]
--      ,report_time
--      ,d.[sql_instance]
-- --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
--, d.snapshot_time
--  FROM [dbo].[sqlwatch_logger_xes_blockers] d
--  	inner join dbo.sqlwatch_logger_snapshot_header h
--		on  h.snapshot_time = d.[snapshot_time]
--		and h.snapshot_type_id = d.snapshot_type_id
--		and h.sql_instance = d.sql_instance
