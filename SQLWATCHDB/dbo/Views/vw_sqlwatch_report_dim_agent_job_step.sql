CREATE VIEW [dbo].[vw_sqlwatch_report_dim_agent_job_step] with schemabinding
	AS 
	select [sql_instance], [sqlwatch_job_id], [step_name], [sqlwatch_job_step_id], [date_last_seen] , [is_record_deleted]
	from dbo.sqlwatch_meta_agent_job_step
