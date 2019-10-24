CREATE VIEW [dbo].[vw_sqlwatch_report_dim_aget_job] with schemabinding
	AS 
	select [sql_instance], [job_name], [job_create_date], [sqlwatch_job_id], [deleted_when] 
		, [pbi_sqlwatch_job_id] = [sql_instance] + '.JOB.' + convert(varchar(10),[sqlwatch_job_id])
	from dbo.sqlwatch_meta_agent_job
