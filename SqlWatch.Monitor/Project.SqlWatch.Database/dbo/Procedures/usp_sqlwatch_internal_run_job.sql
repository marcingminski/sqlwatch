CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_run_job]
	@job_name sysname,
	@fail_on_error bit = 1
as

set nocount on 

declare @job_id uniqueidentifier,
		@job_owner sysname

declare @xp_results table (
	job_id UNIQUEIDENTIFIER NOT NULL,
	last_run_date INT NOT NULL,
	last_run_time INT NOT NULL,
	next_run_date INT NOT NULL,
	next_run_time INT NOT NULL,
	next_run_schedule_id INT NOT NULL,
	requested_to_run INT NOT NULL, -- BOOL
	request_source INT NOT NULL,
	request_source_id sysname COLLATE database_default NULL,
	running INT NOT NULL, -- BOOL
	current_step INT NOT NULL,
	current_retry_attempt INT NOT NULL,
	job_state INT NOT NULL)

select @job_id = job_id, @job_owner = owner_sid 
from msdb.dbo.sysjobs where name = @job_name

insert into @xp_results
exec master.dbo.xp_sqlagent_enum_jobs 1, @job_owner, @job_id

if exists (select top 1 * FROM @xp_results where running = 1)
	begin
		--job is running, quit
		raiserror('Job ''%s'' is already running.',10, 1, @job_name)
        return
	end

declare @startime datetime2(7) = current_timestamp

exec msdb.dbo.sp_start_job @job_name = @job_name
waitfor delay '00:00:01' --without it we get incorrect results from enum_jobs as it does not register immedially

insert into @xp_results
exec master.dbo.xp_sqlagent_enum_jobs 1, @job_owner, @job_id

while exists (select * from @xp_results where running = 1)
	begin
		waitfor delay '00:00:00.500'
		delete from @xp_results
		insert into @xp_results
		exec master.dbo.xp_sqlagent_enum_jobs 1, @job_owner, @job_id
	end

if (select top 1 run_status 
	from msdb.dbo.sysjobhistory 
	where job_id = @job_id and step_id = 0 
	order by run_date desc, run_time desc) = 1 
	begin
		Print 'Job ''' + @job_name + ''' finished successfully in ' + convert(varchar(1000),datediff(millisecond,@startime,current_timestamp)) + 'ms.'
	end
else
	begin
		declare @msg nvarchar(512)
		set @msg = 'Job ' + quotename(@job_name) + ' has not finished successfuly or the state is not known. This does not necessarily mean that the job has failed.'
		if @fail_on_error = 1
			begin
				raiserror(@msg,16, 1, @job_name)
			end
		else
			begin
				print @msg
			end
	end

