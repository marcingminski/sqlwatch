CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_job]
AS

SET XACT_ABORT ON;
BEGIN TRAN

	insert into [dbo].[sqlwatch_meta_agent_job] (sql_instance, job_name, job_create_date)
	select sql_instance=@@SERVERNAME, name, date_created
	from msdb.dbo.sysjobs sj
	left join [dbo].[sqlwatch_meta_agent_job] mj
		on mj.sql_instance = @@SERVERNAME
		and mj.job_name = sj.name collate database_default
		and mj.job_create_date = sj.date_created
	where mj.job_name is null


	insert into [dbo].[sqlwatch_meta_agent_job_step] (sql_instance, sqlwatch_job_id, step_name)
	select sql_instance = @@SERVERNAME, mj.sqlwatch_job_id, ss.step_name
	from msdb.dbo.sysjobsteps ss
	inner join msdb.dbo.sysjobs sj
		on ss.job_id = sj.job_id
	inner join dbo.sqlwatch_meta_agent_job mj
		on mj.job_name = sj.name collate database_default
		and mj.job_create_date = sj.date_created
		and mj.sql_instance = @@SERVERNAME
	left join [dbo].[sqlwatch_meta_agent_job_step] ms
		on ms.sql_instance = mj.sql_instance
		and ms.step_name = ss.step_name
		and ms.sqlwatch_job_id = mj.sqlwatch_job_id
	where ms.step_name is null

COMMIT TRAN