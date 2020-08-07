CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_create_agent_job]
	@print_WTS_command bit,
	@job_owner sysname = null
as
set nocount on;
/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_internal_create_agent_job

 Description:
	Procedure to create sqlwatch related agent jobs. This is purely for code managability. It relies on ##tables with the job definition.
	This is so we can have many procedures requesting job creation (i.e. default sqlwatch jobs and the repository related jobs)
	and one piece of code that actually creates them.

 Parameters
	@print_WTS_command - Whether to print PowerShell code to create Windows Scheduled tasks for SQL Server editions without Agent.
						 passed from the parent procedure
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-12-25	- Marcin Gminski, Initial version
	1.1		2020-01-29	- Marcin Gminski, add job owner
-------------------------------------------------------------------------------------------------------------------
*/

declare @job_description nvarchar(255) = 'https://sqlwatch.io',
		@job_category nvarchar(255) = 'Data Collector',
		@database_name sysname = '$(DatabaseName)',
		@command nvarchar(4000),
		@wts_command varchar(max) = '',
		@sql varchar(max),
		@enabled tinyint = 1,
		@server nvarchar(255)

set @server = @@SERVERNAME

/* fixed job ownership originally submmited by SvenLowry
	https://github.com/marcingminski/sqlwatch/pull/101/commits/8772e56df3aa80849b1dac85405641feb6112e5c 
	
	if no user specified job owner passed, we are going to assume sa, or renamed sa based on the sid. */

if @job_owner is null
	begin
		set @job_owner = (select [name] from syslogins where [sid] = 0x01)
	end



/* create job and steps */
select @sql = replace(replace(convert(nvarchar(max),(select ' if (select name from msdb.dbo.sysjobs where name = ''' + job_name + ''') is null 
	begin
		exec msdb.dbo.sp_add_job @job_name=N''' + job_name + ''',  @owner_login_name=N''' + @job_owner + ''', @category_name=N''' + @job_category + ''', @enabled=' + convert(char(1),job_enabled) + ',@description=''' + @job_description + ''';
		exec msdb.dbo.sp_add_jobserver @job_name=N''' + job_name + ''', @server_name = ''' + @server + ''';
		' + (select 
				' exec msdb.dbo.sp_add_jobstep @job_name=N''' + job_name + ''', @step_name=N''' + step_name + ''',@step_id= ' + convert(varchar(10),step_id) + ',@subsystem=N''' + step_subsystem + ''',@command=''' + replace(step_command,'''','''''') + ''',@on_success_action=' + case when ROW_NUMBER() over (partition by job_name order by step_id desc) = 1 then '1' else '3' end +', @on_fail_action=' + case when ROW_NUMBER() over (partition by job_name order by step_id desc) = 1 then '2' else '3' end + ', @database_name=''' + @database_name + ''''
			 from ##sqlwatch_steps 
			 where ##sqlwatch_steps.job_name = ##sqlwatch_jobs.job_name 
			 order by step_id asc
			 for xml path ('')) + '
		exec msdb.dbo.sp_update_job @job_name=N''' + job_name + ''', @start_step_id=1
		exec msdb.dbo.sp_add_jobschedule @job_name=N''' + job_name + ''', @name=N''' + job_name + ''', @enabled=1,@freq_type=' + convert(varchar(10),freq_type) + ',@freq_interval=' + convert(varchar(10),freq_interval) + ',@freq_subday_type=' + convert(varchar(10),freq_subday_type) + ',@freq_subday_interval=' + convert(varchar(10),freq_subday_interval) + ',@freq_relative_interval=' + convert(varchar(10),freq_relative_interval) + ',@freq_recurrence_factor=' + convert(varchar(10),freq_recurrence_factor) + ',@active_start_date=' + convert(varchar(10),active_start_date) + ',@active_end_date=' + convert(varchar(10),active_end_date) + ',@active_start_time=' + convert(varchar(10),active_start_time) + ',@active_end_time=' + convert(varchar(10),active_end_time) + ';
		Print ''Job ''''' + job_name + ''''' created.''
	end
else
	begin
		Print ''Job ''''' + job_name + ''''' not created because it already exists.''
	end;
	' + case when /* job has not run yet */ h.run_status is null and /* only if its the first deployment */ v.deployment_count = 0 and job_enabled = 1 then 'exec [dbo].[usp_sqlwatch_internal_run_job] @job_name = ''' + job_name + '''' else '' end + '
	'
	from ##sqlwatch_jobs
	outer apply (
		select top 1 run_status 
		from msdb.dbo.sysjobhistory jh
		inner join msdb.dbo.sysjobs sj
			on sj.job_id = jh.job_id
		where sj.name = job_name 
		and step_id = 0 
		order by run_date desc, run_time desc
	) h
	outer apply (
		select count(*) as deployment_count
		from [dbo].[sqlwatch_app_version]
	) v
	order by job_id
	for xml path ('')
)),'&#x0D;',''),'&amp;#x0D;','')

exec (@sql)


WTS:
if @print_WTS_command = 1
	begin
		Print '

----------------------------------------------------------------------------------------------------------------------------------------
Generate PowerShell script to Create Windows Scheduled Task to execute SQLWATCH Collectors on the SQL Express edition
Only create windows tasks on servers that have no agent job, otheriwse double data collection will take place and fail due to PK violation.
The reason we use PowerShell instead of SchTasks is to be able to create multiple actions per task, same as multiple steps per job.
SchTasks does not support more than one /TR parameter.

https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger
----------------------------------------------------------------------------------------------------------------------------------------
'	
/*	It would make sense to have the above in the same cursor but I do not want to change that now, it has been working fine for a long time.
	I will get around to it at some point.
*/

Print 'Fnding Binn path. Ignore any 22001 RegOpenKeyEx() errors below'
declare @val nvarchar(512)

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\100\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\110\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\120\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\130\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\140\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

if @val is null
	begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\\Microsoft\\Microsoft SQL Server\\150\\Tools\\ClientSetup\\', 'Path', @val OUTPUT
	end

Print '

----------------------------------------------------------------------------------------------------------------------------------------
Copy the below into PowerShell ISE and execute
----------------------------------------------------------------------------------------------------------------------------------------'

Print '<# ----------------------------------------------------------------------------------------------------------------------------------------
Scheduled tasks can only accept 261 characters long commands which is not enough for our PowerShell commands.
We are going to dump these into ps1 files and execute these files from the scheduler. Default location will be:
C:\SQLWATCHPS so feel free to change this before executing this script 
---------------------------------------------------------------------------------------------------------------------------------------- #>

$PSPath = "C:\SQLWATCHPS"

<# ----------------------------------------------------------------------------------------------------------------------------------------
Windows Task scheduler normally only runs when the user is logged in. To make it run all the time we have to give it an account under which it will run.
Whilst it is technically possible to run it as SYSTEM, as long as SYSTEM has access to the SQL Server, it is quite insecure. 
Best practice is to create dedicated Windows user i.e. SQLWATCHUSER and *** GRANT BATCH LOGON RIGHTS *** and required access to the SQL Server. 
You can read more about task principals here: https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtaskprincipal

In your enviroment you will want something like:
$User = "sqlwatch"
$Password = "UserPassword"
$LogonType = "Password"

However, to make this example and scripting easier, we are going to asume LOCALSERVICE. 
Note that the account will need access to the SQL Server and the SQLWATCH database according to the access requirements.
---------------------------------------------------------------------------------------------------------------------------------------- #>

$User = "LOCALSERVICE" #Change in your environemnt to a dedicated user
$LogonType = "ServiceAccount"

<# ---------------------------------------------------------------------------------------------------------------------------------------- #>

If (!(Test-Path $PSPath)) {
    New-Item $PSPath -ItemType Directory
   }
'

declare @job_name sysname,
		@step_name sysname,
		@step_command varchar(max),
		@step_subsystem sysname,
		@step_id int,
		@start_time int,
		@string_time varchar(10),
		@freq_type int,
		@freq_interval int,
		@freq_subday_type int,
		@freq_subday_interval int,
		@task_name sysname

declare cur_jobs cursor for
select distinct task_name = j.job_name, j.job_name, active_start_time, freq_type, freq_interval, freq_subday_type, freq_subday_interval, job_enabled
from ##sqlwatch_jobs j

open cur_jobs

fetch next from cur_jobs into @task_name, @job_name, @start_time, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @enabled

while @@FETCH_STATUS = 0
	begin
		Print '
## ' + @job_name
		set @command = ''
		set @command = '$actions=@()'
		set @string_time = right('000000' + convert(varchar(6),@start_time), 6)

		declare cur_job_steps cursor
		for select step_name, step_command, step_subsystem, step_id
		from ##sqlwatch_steps
		where job_name = @job_name
		order by step_id

		open cur_job_steps
		fetch next from cur_job_steps 
		into @step_name, @step_command, @step_subsystem, @step_id

		while @@FETCH_STATUS = 0
			begin

				if @step_subsystem = 'TSQL'
					begin
						set @command = @command + char(10) + '$actions+=New-ScheduledTaskAction –Execute ''' + @val + 'osql.exe '' -Argument ''-E -S "' + @server + '" -d "' + @database_name + '" -Q "' + @step_command + ';"' + ''''
					end

				if @step_subsystem = 'PowerShell'
					begin
						set @command = @command + char(10) + 'If (!(Test-Path "$PSPath\' + @job_name + '")) {
    New-Item "$PSPath\' + @job_name + '" -ItemType Directory
   }'
						set @command = @command + char(10) + '@''
' + @step_command + '
''@ | Out-File "$PSPath\' + @job_name + '\' + @step_name +'.ps1"'
						set @command = @command + char(10) + '$actions+=New-ScheduledTaskAction –Execute ''PowerShell.exe'' -Argument ' + '$' + '(''-file "''+' + ' $' + '( $PSPath ) + ''\' + @job_name + '\' + @step_name +'.ps1"'' )'
					end

				fetch next from cur_job_steps 
				into @step_name, @step_command, @step_subsystem, @step_id
			end

		set @string_time = left(@string_time, 2) + ':' + right(left(@string_time, 4), 2) + ':' + right(left(@string_time, 8), 2)

		set @command = @command + char(10) + '$trigger=New-ScheduledTaskTrigger -' + case @freq_type
			when 1 then 'Once'
			when 4 then 'Daily'
			when 8 then 'Weekly'
			when 16 then 'Monthly'
			end + ' -At ''' + convert(varchar(10),@string_time) + ''''

		set @command = @command + char(10) + '$principal=New-ScheduledTaskPrincipal -UserId $User -LogonType $LogonType'
		set @command = @command + char(10) + '$task=New-ScheduledTask -Action $actions -Trigger $trigger -Principal $principal'
		set @command = @command + char(10) + 'if ( $Password -ne "" -and $Password -ne $null ) {
Register-ScheduledTask "' + @task_name + '" -InputObject $task -User $User -Password $Password
} else {
Register-ScheduledTask "' + @task_name + '" -InputObject $task -User $User
}'
		
		/*	The amount of time between each restart of the task. The format for this string is PDTHMS (for example, "PT5M" is 5 minutes, "PT1H" is 1 hour, and "PT20M" is 20 minutes). 
			The maximum time allowed is 31 days, and the minimum time allowed is 1 minute.	*/
		set @command = @command + char(10) + '$task = Get-ScheduledTask -TaskName "' + @task_name + '"'

		/* It's all fun and games until you realise you have to translate SQL frequency types and intervals into the repetition format. 
			Surely these two teams at MS could talk...I am only going to support frequencies and types used in SQLWATCH otherwise it's quite a task. 
			https://docs.microsoft.com/en-us/windows/win32/taskschd/repetitionpattern-interval?redirectedfrom=MSDN
			https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-schedule-transact-sql		
			*/
		set @command = @command + char(10) + '$task.Triggers.repetition.Duration = "P' + case @freq_type
			when 4 then + convert(varchar(10),@freq_interval)
			else '' end + 'D"'

		set @command = @command + char(10) + '$task.Triggers.repetition.Interval = "PT' + case @freq_subday_type
				when 2 then '1M' --Task scheduler does not support seconds, most frequent it can run is 1 minute.
				when 4 then convert(varchar(10),@freq_subday_interval) + 'M'
				when 8 then convert(varchar(10),@freq_subday_interval) + 'H'
				else '' end + '"'		
		set @command = @command + char(10) + 'if ( $Password -ne "" -and $Password -ne $null ) {
$task | Set-ScheduledTask -User $User -Password $Password
} else {
$task | Set-ScheduledTask -User $User
}'

		if @enabled = 0
			begin
				set @command = @command + char(10) + 'Disable-ScheduledTask -TaskName "' + @task_name + '"'
			end
		Print @command 
		close cur_job_steps
		deallocate cur_job_steps
		fetch next from cur_jobs into @task_name, @job_name, @start_time, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @enabled
	end

close cur_jobs
deallocate cur_jobs


if object_id('tempdb..##sqlwatch_steps') is not null
	drop table ##sqlwatch_steps

if object_id('tempdb..##sqlwatch_jobs') is not null
	drop table ##sqlwatch_jobs

end