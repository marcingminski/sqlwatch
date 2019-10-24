CREATE VIEW [dbo].[vw_sqlwatch_report_dim_agent_job_step] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_job_id], [step_name], [sqlwatch_job_step_id], [deleted_when] 
		,[pbi_sqlwatch_job_id] = [sql_instance] + '.JOB.' + convert(varchar(10),[sqlwatch_job_id])
		,pbi_jsqlwatch_job_step_id = [sql_instance] + '.JOB.' + convert(varchar(10),[sqlwatch_job_id]) + '.STEP.' + convert(varchar(10),sqlwatch_job_step_id)
	from dbo.sqlwatch_meta_agent_job_step
