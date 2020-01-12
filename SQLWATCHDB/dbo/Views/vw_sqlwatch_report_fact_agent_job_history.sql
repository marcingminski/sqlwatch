CREATE VIEW [dbo].[vw_sqlwatch_report_fact_agent_job_history] with schemabinding
as
select 
	  jh.sqlwatch_job_id
	, jh.sqlwatch_job_step_id
	, jh.sql_instance

	, j.job_name
	, js.step_name

	, jh.[sysjobhistory_step_id]
	, [run_duration_s]
	, [run_date]
	, [run_status]
	, [run_status_desc] = case [run_status]
			when 0 then 'Failed'
			when 1 then 'Succeeded'
			when 2 then 'Retry'
			when 3 then 'Canceled'
			when 4 then 'In Progress'
		else 'Unknown Status' end
	,report_time
	,[end_date]=dateadd(s,[run_duration_s],[run_date])
	,[show_agent_history] = convert(bit,1)
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, jh.snapshot_time
, sh.snapshot_type_id
, jh.run_date_utc
from [dbo].[sqlwatch_logger_agent_job_history] jh

inner join dbo.sqlwatch_logger_snapshot_header sh
	on sh.sql_instance = jh.sql_instance
	and sh.snapshot_time = jh.[snapshot_time]
	and sh.snapshot_type_id = jh.snapshot_type_id

inner join [dbo].[sqlwatch_meta_agent_job_step] js
	on jh.sql_instance = js.sql_instance
	and jh.sqlwatch_job_id = js.sqlwatch_job_id
	and jh.sqlwatch_job_step_id = js.sqlwatch_job_step_id

inner join [dbo].[sqlwatch_meta_agent_job] j
	on j.sql_instance = jh.sql_instance
	and j.sqlwatch_job_id = jh.sqlwatch_job_id