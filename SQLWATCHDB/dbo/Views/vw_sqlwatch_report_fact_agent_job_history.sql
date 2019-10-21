CREATE VIEW [dbo].[vw_sqlwatch_report_fact_agent_job_history] with schemabinding
as
select 
	  aj.sql_instance
	, aj.[job_name]
	, js.[step_name]

	, jh.[sysjobhistory_step_id]
	, [run_duration_s]
	, [run_date]
	, [run_status_desc] = case [run_status]
			when 0 then 'Failed'
			when 1 then 'Succeeded'
			when 2 then 'Retry'
			when 3 then 'Canceled'
			when 4 then 'In Progress'
		else 'Unknown Status' end
	,report_time
from [dbo].[sqlwatch_meta_agent_job] aj

inner join [dbo].[sqlwatch_meta_agent_job_step] js
	on js.[sqlwatch_job_id] = aj.[sqlwatch_job_id]
	and js.[sql_instance] = aj.[sql_instance]

inner join [dbo].[sqlwatch_logger_agent_job_history] jh
	on jh.[sql_instance] = aj.[sql_instance]
	and jh.[sqlwatch_job_id] = js.[sqlwatch_job_id]
	and jh.[sqlwatch_job_step_id] = js.[sqlwatch_job_step_id]

	inner join dbo.sqlwatch_logger_snapshot_header sh
		on sh.sql_instance = jh.sql_instance
		and sh.snapshot_time = jh.[snapshot_time]
		and sh.snapshot_type_id = jh.snapshot_type_id