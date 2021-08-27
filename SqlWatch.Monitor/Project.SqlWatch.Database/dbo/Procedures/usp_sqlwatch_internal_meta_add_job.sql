CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_job]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	select 
		[job_id]
		, [job_name]
		, [date_created]
		, [step_name]
		, [step_id]
		, [step_uid]
	into #t
	from openxml (@xdoc, '/MetaDataSnapshot/sys_jobs/row',1) 
		with (
			job_id uniqueidentifier,
			job_name sysname,
			date_created datetime2(3),
			step_name sysname,
			step_id int,
			step_uid uniqueidentifier
		) t;

	merge [dbo].[sqlwatch_meta_agent_job] as target
	using (
		select distinct
			job_name
			, date_created
			, sql_instance = @sql_instance
			, job_id
			from #t)
	as source
	on (    target.sql_instance = source.sql_instance
		and target.job_name = source.job_name collate database_default
		and target.job_create_date = source.date_created
		)
	when not matched by target then
		insert (sql_instance, job_name, job_create_date, job_id)
		values (source.sql_instance, source.job_name, source.date_created, source.job_id)

	when matched then
		update set
			[date_last_seen] = GETUTCDATE(),
			job_id = source.job_id;

	merge [dbo].[sqlwatch_meta_agent_job_step] as target
	using (
		select 
			sql_instance = @sql_instance
			, mj.sqlwatch_job_id
			, sj.step_name
		from #t sj
		inner join dbo.sqlwatch_meta_agent_job mj
			on mj.job_name = sj.job_name collate database_default
			and mj.job_create_date = sj.date_created
			and mj.sql_instance = @sql_instance
	) as source
	on (
			target.sql_instance = source.sql_instance
		and target.step_name = source.step_name collate database_default
		and target.sqlwatch_job_id = source.sqlwatch_job_id
	)

	when not matched by source and @sql_instance is not null and target.sql_instance = @sql_instance then
		update set [is_record_deleted] = 1

	when not matched by target then 
		insert (sql_instance, sqlwatch_job_id, step_name)
		values (source.sql_instance, source.sqlwatch_job_id, source.step_name)

	when matched then
		update set
			[date_last_seen] = GETUTCDATE();
end;