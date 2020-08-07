CREATE PROCEDURE [dbo].[usp_sqlwatch_config_repository_create_agent_jobs]
	@threads tinyint = 1,
	@remove_existing bit = 0,
	@print_WTS_command bit = 0
as

begin
/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_config_set_repository_agent_jobs

 Description:
	Creates default SQLWATCH Agent jobs for the central repostory collector via linked server. Only required
	when collectint data from remotes via linked server. NOT required when using SSIS. 

 Parameters
	@remove_existing	-	Force delete jobs so they can be re-created.
	@print_WTS_command	-	Print Command to create equivalent tasks in Windows Task scheduler for editions that have no
							SQL Agent i.e. Express.
	@threads			-	number of worker (thread) jobs to create.
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-12-25	- Marcin Gminski, Initial version
-------------------------------------------------------------------------------------------------------------------
*/

	set nocount on;

	declare @sql varchar(max) = '',
			@server nvarchar(255) = @@SERVERNAME,
			@enabled tinyint = 1,
			@threads_count tinyint = 0,
			@job_name sysname,
			@start_time int = 6

	if @remove_existing = 1
		begin
			select @sql = @sql + 'exec msdb.dbo.sp_delete_job @job_id=N''' + convert(varchar(255),job_id) + ''';' 
			from msdb.dbo.sysjobs
	where name like 'SQLWATCH-REPOSITORY-%'
			exec (@sql)
			Print 'Existing SQLWATCH repository jobs (SQLWATCH-REPOSITORY-%) deleted'
		end


	create table ##sqlwatch_jobs (
		job_id tinyint identity (1,1),
		job_name sysname primary key,
		freq_type int, 
		freq_interval int, 
		freq_subday_type int, 
		freq_subday_interval int, 
		freq_relative_interval int, 
		freq_recurrence_factor int, 
		active_start_date int, 
		active_end_date int, 
		active_start_time int, 
		active_end_time int,
		job_enabled tinyint,
		)


	create table ##sqlwatch_steps (
		step_name sysname,
		step_id int,
		job_name sysname,
		step_subsystem sysname,
		step_command varchar(max)
		)

insert into ##sqlwatch_jobs

			/* JOB_NAME						freq:		type,	interval,	subday_type,	subday_intrval, relative_interval,	recurrence_factor,	start_date, end_date, start_time,	end_time,	enabled */
	values	('SQLWATCH-REPOSITORY-IMPORT-ENQUEUE',		4,		1,			4,				1,				0,					1,					20180101,	99991231, @start_time,	235959,		@enabled)

insert into ##sqlwatch_steps
			/* step name											step_id,	job_name								subsystem,	command */
	values	('dbo.usp_sqlwatch_repository_remote_table_enqueue',		1,			'SQLWATCH-REPOSITORY-IMPORT-ENQUEUE',	'TSQL',		'exec dbo.usp_sqlwatch_repository_remote_table_enqueue')


while @threads_count < @threads
	begin
		set @threads_count = @threads_count + 1
		set @start_time = @start_time + 1
		set @job_name = 'SQLWATCH-REPOSITORY-IMPORT-T' + convert(varchar(10),@threads_count)
		insert into ##sqlwatch_jobs

					/* JOB_NAME		freq:		type,	interval,	subday_type,	subday_intrval, relative_interval,	recurrence_factor,	start_date, end_date, start_time,	end_time,	enabled */
			values	(@job_name,					4,		1,			4,				1,				0,					1,					20180101,	99991231, @start_time,	235959,		@enabled)

		insert into ##sqlwatch_steps
					/* step name													step_id,	job_name	subsystem,	command */
			values	('dbo.usp_sqlwatch_repository_remote_table_import',		1,		@job_name,	'TSQL',		'exec dbo.usp_sqlwatch_repository_remote_table_import')
	end

exec [dbo].[usp_sqlwatch_internal_create_agent_job] @print_WTS_command = @print_WTS_command

end