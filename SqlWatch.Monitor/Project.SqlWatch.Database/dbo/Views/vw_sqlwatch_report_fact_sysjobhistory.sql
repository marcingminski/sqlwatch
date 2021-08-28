CREATE VIEW [dbo].[vw_sqlwatch_report_fact_sysjobhistory] with schemabinding
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
	,[end_date]=dateadd(s,[run_duration_s],[run_date])
	,[show_agent_history] = convert(bit,1)
	, jh.snapshot_time
	, jh.snapshot_type_id
	, jh.run_date_utc
from [dbo].[sqlwatch_logger_sysjobhistory] jh

inner join [dbo].[sqlwatch_meta_agent_job_step] js
	on jh.sql_instance = js.sql_instance
	and jh.sqlwatch_job_id = js.sqlwatch_job_id
	and jh.sqlwatch_job_step_id = js.sqlwatch_job_step_id

inner join [dbo].[sqlwatch_meta_agent_job] j
	on j.sql_instance = jh.sql_instance
	and j.sqlwatch_job_id = jh.sqlwatch_job_id;