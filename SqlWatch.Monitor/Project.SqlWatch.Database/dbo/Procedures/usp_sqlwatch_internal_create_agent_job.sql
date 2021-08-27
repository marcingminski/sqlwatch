CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_create_agent_job]
	@print_WTS_command bit,
	@job_owner sysname = null
as
begin
	set nocount on;

	declare @job_description nvarchar(255),
			@job_category nvarchar(255) = 'Data Collector',
			@database_name sysname = '$(DatabaseName)',
			@command nvarchar(4000),
			@wts_command varchar(max) = '',
			@sql varchar(max),
			@enabled tinyint = 1,
			@server nvarchar(255),
			@job_name nvarchar(255),
			@job_enabled bit,
			@step_name nvarchar(255),
			@step_id int,
			@step_subsystem nvarchar(255),
			@step_command nvarchar(max),
			@on_success_action int,
			@on_fail_action int,
			@freq_interval int, 
			@freq_subday_type int, 
			@freq_subday_interval int, 
			@freq_relative_interval int, 
			@freq_recurrence_factor int, 
			@active_start_date int, 
			@active_end_date int, 
			@active_start_time int, 
			@active_end_time int,
			@freq_type int
			;

	set @server = @@SERVERNAME;

	/* fixed job ownership originally submmited by SvenLowry
		https://github.com/marcingminski/sqlwatch/pull/101/commits/8772e56df3aa80849b1dac85405641feb6112e5c 
	
		if no user specified job owner passed, we are going to assume sa, or renamed sa based on the sid. */

	if @job_owner is null
		begin
			set @job_owner = (select [name] from syslogins where [sid] = 0x01)
		end

	--adding database name to the job name if not standard SQLWATCH for better clarity and to be able to deploy multiple SQLWATCH databases and corresponding jobs.
	if '$(DatabaseName)' not in ('sqlwatch','SQLWATCH')
		begin
			update ##sqlwatch_jobs set job_name = replace(job_name,'SQLWATCH-','SQLWATCH-[' +  '$(DatabaseName)' + ']-')
			update ##sqlwatch_steps set job_name = replace(job_name,'SQLWATCH-','SQLWATCH-[' +  '$(DatabaseName)' + ']-')
		end

	declare cur_jobs cursor fast_forward for
	select job_name, 
			job_enabled, 
			job_description,
			freq_interval , 
			freq_subday_type , 
			freq_subday_interval , 
			freq_relative_interval , 
			freq_recurrence_factor , 
			active_start_time , 
			freq_type
	from ##sqlwatch_jobs

	open cur_jobs;

	fetch next from cur_jobs
	into @job_name,
			@job_enabled,
			@job_description,
			@freq_interval , 
			@freq_subday_type , 
			@freq_subday_interval , 
			@freq_relative_interval , 
			@freq_recurrence_factor , 
			@active_start_time , 
			@freq_type
			;

	while @@FETCH_STATUS = 0 
		begin

			print 'Job: ' + @job_name;

			set @job_description = case when @job_description is null then '' else char(10) end + 'https://sqlwatch.io';

			--does the job exist?
			if [dbo].[ufn_sqlwatch_get_agent_job_status](@job_name) = -1
				begin

					exec msdb.dbo.sp_add_job 
						@job_name = @job_name,
						@owner_login_name = @job_owner,
						@category_name = @job_category,
						@enabled = @job_enabled,
						@description = @job_description;

					exec msdb.dbo.sp_add_jobserver 
						@job_name = @job_name, 
						@server_name = @server;

					declare cur_job_steps cursor for
					select step_name, step_id = ROW_NUMBER() OVER (ORDER BY step_id), step_subsystem, step_command
					from ##sqlwatch_steps
					where job_name = @job_name

					open cur_job_steps

					fetch next from cur_job_steps
					into @step_name, @step_id, @step_subsystem, @step_command;

					while @@FETCH_STATUS = 0
						begin
				
							set @on_success_action = case when @step_id = 1 then 1 else 3 end;
							set @on_fail_action = case when @step_id = 1 then 2 else 3 end;

							exec msdb.dbo.sp_add_jobstep 
								@job_name = @job_name,
								@step_name = @step_name,
								@step_id = @step_id,
								@subsystem = @step_subsystem,
								@command = @step_command,
								@on_success_action = @on_success_action, 
								@on_fail_action = @on_fail_action, 
								@database_name = @database_name;

							fetch next from cur_job_steps
							into @step_name, @step_id, @step_subsystem, @step_command
						end;

					close cur_job_steps;
					deallocate cur_job_steps;

					exec msdb.dbo.sp_update_job 
						@job_name = @job_name,
						@start_step_id = 1;

					if @freq_type is not null
						begin
							exec msdb.dbo.sp_add_jobschedule 
								@job_name = @job_name, 
								@name = @job_name,
								@enabled=1,
								@freq_type=@freq_type,
								@freq_interval=@freq_interval,
								@freq_subday_type=@freq_subday_type,
								@freq_subday_interval=@freq_subday_interval,
								@freq_relative_interval=@freq_relative_interval,
								@freq_recurrence_factor=@freq_recurrence_factor,
								@active_start_date=20180101,
								@active_end_date=99991231,
								@active_start_time=@active_start_time,
								@active_end_time=235959
						end;




				end;

				fetch next from cur_jobs
				into @job_name,
						@job_enabled,
						@job_description,
						@freq_interval , 
						@freq_subday_type , 
						@freq_subday_interval , 
						@freq_relative_interval , 
						@freq_recurrence_factor , 
						@active_start_time , 
						@freq_type
		end;

	close cur_jobs;
	deallocate cur_jobs;


	--	if object_id('tempdb..##sqlwatch_steps') is not null
	--		drop table ##sqlwatch_steps

	--	if object_id('tempdb..##sqlwatch_jobs') is not null
	--		drop table ##sqlwatch_jobs

end;