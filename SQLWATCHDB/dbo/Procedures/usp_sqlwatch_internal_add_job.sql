CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_job]
AS

SET XACT_ABORT ON;
BEGIN TRAN

	merge [dbo].[sqlwatch_meta_agent_job] as target
	using msdb.dbo.sysjobs as source
	on (    target.sql_instance = @@SERVERNAME
		and target.job_name = source.name collate database_default
		and target.job_create_date = source.date_created
		)
	when not matched by target then
		insert (sql_instance, job_name, job_create_date)
		values (@@SERVERNAME, source.name, source.date_created);
	--when not matched by source then
	--	update set deleted_when = GETUTCDATE();

	--insert into [dbo].[sqlwatch_meta_agent_job] (sql_instance, job_name, job_create_date)
	--select sql_instance=@@SERVERNAME, name, date_created
	--from msdb.dbo.sysjobs sj
	--left join [dbo].[sqlwatch_meta_agent_job] mj
	--	on mj.sql_instance = @@SERVERNAME
	--	and mj.job_name = sj.name collate database_default
	--	and mj.job_create_date = sj.date_created
	--where mj.job_name is null

	merge [dbo].[sqlwatch_meta_agent_job_step] as target
	using (
		select sql_instance = @@SERVERNAME, mj.sqlwatch_job_id, ss.step_name
		from msdb.dbo.sysjobsteps ss
		inner join msdb.dbo.sysjobs sj
			on ss.job_id = sj.job_id
		inner join dbo.sqlwatch_meta_agent_job mj
			on mj.job_name = sj.name collate database_default
			and mj.job_create_date = sj.date_created
			and mj.sql_instance = @@SERVERNAME	
	) as source
	on (
			target.sql_instance = source.sql_instance
		and target.step_name = source.step_name collate database_default
		and target.sqlwatch_job_id = source.sqlwatch_job_id
	)
	when not matched by target then 
		insert (sql_instance, sqlwatch_job_id, step_name)
		values (@@SERVERNAME, source.sqlwatch_job_id, source.step_name);

	--when not matched by source and target.sql_instance = @@SERVERNAME then
	--	update set deleted_when = GETUTCDATE();

	--insert into [dbo].[sqlwatch_meta_agent_job_step] (sql_instance, sqlwatch_job_id, step_name)
	--select sql_instance = @@SERVERNAME, mj.sqlwatch_job_id, ss.step_name
	--from msdb.dbo.sysjobsteps ss
	--inner join msdb.dbo.sysjobs sj
	--	on ss.job_id = sj.job_id
	--inner join dbo.sqlwatch_meta_agent_job mj
	--	on mj.job_name = sj.name collate database_default
	--	and mj.job_create_date = sj.date_created
	--	and mj.sql_instance = @@SERVERNAME
	--left join [dbo].[sqlwatch_meta_agent_job_step] ms
	--	on ms.sql_instance = mj.sql_instance
	--	and ms.step_name = ss.step_name collate database_default
	--	and ms.sqlwatch_job_id = mj.sqlwatch_job_id
	--where ms.step_name is null

COMMIT TRAN