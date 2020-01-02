CREATE VIEW [dbo].[vw_sqlwatch_report_fact_agent_job_history] with schemabinding
as
select 
	  jh.sqlwatch_job_id
	, jh.sqlwatch_job_step_id
	, jh.sql_instance

	, j.job_name
	, j.step_name

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
from [dbo].[sqlwatch_logger_agent_job_history] jh

inner join dbo.sqlwatch_logger_snapshot_header sh
	on sh.sql_instance = jh.sql_instance
	and sh.snapshot_time = jh.[snapshot_time]
	and sh.snapshot_type_id = jh.snapshot_type_id


	/*  using outer apply instead of inner join is SOO MUCH slower...
		BUT it only applies to the columns we select.
		If we do not select any columns from the outer apply, it does not get applied whereas joins
		always do whether we select columns or not. 99% of the time these views will feed PowerBI wher only IDs are required
		and small subset of columns queried. that 1% will be DBAs querying views directly in SSMS (TOP (1000)) in which case, 
		having actual names instead alongisde IDs will make their life easier with small increase in performane penalty */
	outer apply (
		select aj.job_name, ajs.step_name
		from [dbo].[sqlwatch_meta_agent_job] aj
		inner join [dbo].[sqlwatch_meta_agent_job_step] ajs
			on aj.sql_instance = ajs.sql_instance
			and aj.sqlwatch_job_id = ajs.sqlwatch_job_id
		where aj.sql_instance = jh.sql_instance
		and aj.sqlwatch_job_id = jh.sqlwatch_job_id
		and ajs.sqlwatch_job_step_id = jh.sqlwatch_job_step_id
	) j