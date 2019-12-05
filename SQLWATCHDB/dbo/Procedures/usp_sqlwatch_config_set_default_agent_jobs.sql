CREATE PROCEDURE [dbo].[usp_sqlwatch_config_set_default_agent_jobs]
	@remove_existing bit = 0,
	@print_WTS_command bit = 0
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_config_set_default_agent_jobs

 Description:
	Creates default SQLWATCH Agent jobs. This procedure is triggered via post-deploy script and creates all SQLWATCH
	jobs during the initial deployment. Once created, the jobs will never be modified during subsequent upgrades. 
	This is to prevent overwriting user-defined schedules. To overwrite job i.e. to fix a bug delete existing job first.
	Alternatively, parameter @remove_existing can be used to delete jobs automatically. This will also delete jobs' history.

 Parameters
	@remove_existing	-	Force delete jobs so they can be re-created.
	@print_WTS_command	-	Print Command to create equivalent tasks in Windows Task scheduler for editions that have no
							SQL Agent i.e. Express.
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-xx-xx	- Marcin Gminski, Initial version
	1.1		2019-12-04	- Marcin Gminski, Print command to create Windows Scheduled Tasks for editions without agent
-------------------------------------------------------------------------------------------------------------------
*/


/* create jobs */
declare @sql varchar(max)
declare @job_description nvarchar(255) = 'https://sqlwatch.io'
declare @job_category nvarchar(255) = 'Data Collector'
declare @database_name sysname = '$(DatabaseName)'
declare @command nvarchar(4000)
declare @wts_command varchar(max) = ''

declare @server nvarchar(255)
set @server = @@SERVERNAME


set @sql = ''
if @remove_existing = 1
	begin
		select @sql = @sql + 'exec msdb.dbo.sp_delete_job @job_id=N''' + convert(varchar(255),job_id) + ''';' 
		from msdb.dbo.sysjobs
where name like 'SQLWATCH-%'

		exec (@sql)
	end

set @sql = ''
create table #jobs (
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


create table #steps (
	step_name sysname,
	step_id int,
	job_name sysname,
	step_subsystem sysname,
	step_command varchar(max)
	)

declare @enabled tinyint = 1
set @enabled = case when object_id('master.dbo.sp_whoisactive') is not null or object_id('dbo.sp_whoisactive') is not null then 1 else 0 end

/* job definition */
insert into #jobs

			/* JOB_NAME                 freq:	type,	interval,	subday_type,	subday_intrval, relative_interval,	recurrence_factor,	start_date, end_date, start_time,	end_time,	enabled */
	values	('SQLWATCH-LOGGER-WHOISACTIVE',		4,		1,			2,				15,				0,					0,					20180101,	99991231, 0,			235959,		@enabled),
			('SQLWATCH-LOGGER-PERFORMANCE',		4,		1,			4,				1,				0,					1,					20180101,	99991231, 12,			235959,		1),
			('SQLWATCH-LOGGER-DISK-UTILISATION',4,		1,			8,				1,				0,					1,					20180101,	99991231, 437,			235959,		1),
			('SQLWATCH-LOGGER-INDEXES',			4,		1,			8,				6,				0,					1,					20180101,	99991231, 420,			235959,		1),
			('SQLWATCH-LOGGER-AGENT-HISTORY',	4,		1,			4,				10,				0,					1,					20180101,	99991231, 0,			235959,		1),

			('SQLWATCH-INTERNAL-RETENTION',		4,		1,			8,				1,				0,					1,					20180101,	99991231, 20,			235959,		1),
			('SQLWATCH-INTERNAL-CONFIG',		4,		1,			8,				1,				0,					1,					20180101,	99991231, 26,			235959,		1),
			('SQLWATCH-INTERNAL-TRENDS',		4,		1,			4,				60,				0,					1,					20180101,	99991231, 150,			235959,		1),
			('SQLWATCH-INTERNAL-ACTIONS',		4,		1,			2,				15,				0,					1,					20180101,	99991231, 2,			235959,		1),
			('SQLWATCH-INTERNAL-CHECKS',		4,		1,			4,				1,				0,					1,					20180101,	99991231, 43,			235959,		1)

			--('SQLWATCH-USER-REPORTS',			4,		1,			1,				0,				0,					1,					20180101,	99991231, 80000,		235959,		1)


/* step definition */

/*  Normally, the SQLWATCH-INTERNAL-META-CONFIG runs any metadata config procedures that collect reference data every hour. by reference data
	we mean list of databases, tables, jobs, indexes etc. this is to reduce load during more frequent collectors such as the performance collector.
	For obvious reasons, we would not want to collect list of tables every minute as that would be pointless however, in case of less frequent jobs such as disk collector 
	and index collection, or those more time consuming and resource heavy, by exception, we will run meta data collection part of the data collector job rather than the standard meta-config job 
	SQLWATCH tries to be as lightweight as possible and will not collect any data unles required.
*/

insert into #steps
			/* step name								step_id,	job_name							subsystem,	command */
	values	('dbo.usp_sqlwatch_logger_whoisactive',		1,			'SQLWATCH-LOGGER-WHOISACTIVE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_whoisactive'),

			('dbo.usp_sqlwatch_logger_performance',		1,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_performance'),
			('dbo.usp_sqlwatch_logger_xes_waits',		2,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_waits'),
			('dbo.usp_sqlwatch_logger_xes_blockers',	3,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_blockers'),
			('dbo.usp_sqlwatch_logger_xes_diagnostics',	4,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_diagnostics'),
			('dbo.usp_sqlwatch_logger_xes_long_queries',5,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_long_queries'),

			('dbo.usp_sqlwatch_trend_perf_os_performance_counters',1,'SQLWATCH-INTERNAL-TRENDS',		'TSQL',		'exec dbo.usp_sqlwatch_trend_perf_os_performance_counters'),

			--('dbo.usp_sqlwatch_internal_process_reports',1,			'SQLWATCH-USER-REPORTS',			'TSQL',		'exec dbo.usp_sqlwatch_internal_process_reports @report_batch_id = 1'),

			('dbo.usp_sqlwatch_internal_process_checks',1,			'SQLWATCH-INTERNAL-CHECKS',				'TSQL',		'exec dbo.usp_sqlwatch_internal_process_checks'),

			('Process Actions',							1,			'SQLWATCH-INTERNAL-ACTIONS',		'PowerShell','
$output = "x"
while ($output -ne $null) { 
	$output = Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -MaxCharLength 2147483647 -Query "set xact_abort on
	begin tran
		;with cte_get_message as (
		  select top 1 *
		  from [dbo].[sqlwatch_meta_action_queue]
		  where [exec_status] is null
		  order by [time_queued]
		)
		update cte_get_message
			set [exec_status] = ''PROCESSING''
			output deleted.[action_exec], deleted.[action_exec_type], deleted.[queue_item_id]
	commit tran"

	$status = ""
	$queue_item_id = $output.queue_item_id
    $operation = ""
	$ErrorOutput = ""
	
	if ( $output -ne $null) {
		if ( $output.action_exec_type -eq "T-SQL" ) {
			try {
				Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -ErrorAction "Stop" -Query $output.action_exec -MaxCharLength 2147483647
			}
			catch {
				$ErrorOutput = $error[0] -replace "''", "''''"
			}
		}

		if ( $output.action_exec_type -eq "PowerShell" ) {
			try {
				$action_exec = $output.action_exec
				Invoke-Expression $output.action_exec
			}
			catch {
				$ErrorOutput = $_.Exception.Message
				}
		}

       if ($ErrorOutput -ne "") {
 			$query = "update [dbo].[sqlwatch_meta_action_queue] set [exec_status] = ''FAILED'' where queue_item_id = $queue_item_id;
					exec [dbo].[usp_sqlwatch_internal_log]
							@procces_name = ''PowerShell'',
							@process_stage = ''6DC68414-915F-4B52-91B6-4D0B6018243B'',
							@process_message = ''$ErrorOutput'',
							@process_message_type = ''ERROR'' "
        } else {
			$query = "update [dbo].[sqlwatch_meta_action_queue] set [exec_status] = ''OK'' where queue_item_id = $queue_item_id"
        }
		Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query $query
		Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query "delete from [dbo].[sqlwatch_meta_action_queue] [exec_status] = ''OK'' and [time_queued] > dateadd(day,-1,sysdatetime())"
	}
}'),
			
			('dbo.usp_sqlwatch_logger_agent_job_history', 1,		'SQLWATCH-LOGGER-AGENT-HISTORY',		'TSQL',		'exec dbo.usp_sqlwatch_logger_agent_job_history'),

			('dbo.usp_sqlwatch_internal_retention',		1,			'SQLWATCH-INTERNAL-RETENTION',		'TSQL',		'exec dbo.usp_sqlwatch_internal_retention'),
			('dbo.usp_sqlwatch_internal_purge_deleted_items',2,		'SQLWATCH-INTERNAL-RETENTION',		'TSQL',		'exec dbo.usp_sqlwatch_internal_purge_deleted_items'),

			('dbo.usp_sqlwatch_logger_disk_utilisation',1,			'SQLWATCH-LOGGER-DISK-UTILISATION',	'TSQL',		'exec dbo.usp_sqlwatch_logger_disk_utilisation'),
			('Get-WMIObject Win32_Volume',		2,					'SQLWATCH-LOGGER-DISK-UTILISATION',	'PowerShell', N'
#https://msdn.microsoft.com/en-us/library/aa394515(v=vs.85).aspx
#driveType 3 = Local disk
Get-WMIObject Win32_Volume | ?{$_.DriveType -eq 3} | %{
    $VolumeName = $_.Name
    $FreeSpace = $_.Freespace
    $Capacity = $_.Capacity
    $VolumeLabel = $_.Label
    $FileSystem = $_.Filesystem
    $BlockSize = $_.BlockSize
    Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query "
	 exec [dbo].[usp_sqlwatch_internal_add_os_volume] 
		@volume_name = ''$VolumeName'', 
		@label = ''$VolumeLabel'', 
		@file_system = ''$FileSystem'', 
		@block_size = ''$BlockSize''
	 exec [dbo].[usp_sqlwatch_logger_disk_utilisation_os_volume] 
		@volume_name = ''$VolumeName'',
		@volume_free_space_bytes = $FreeSpace,
		@volume_total_space_bytes = $Capacity
    " 
}'),

			('dbo.usp_sqlwatch_internal_add_index',			1,		'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_internal_add_index'),
			('dbo.usp_sqlwatch_internal_add_index_missing',	2,		'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_internal_add_index_missing'),	
			('dbo.usp_sqlwatch_logger_missing_index_stats',	3,		'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_logger_missing_index_stats'),
			('dbo.usp_sqlwatch_logger_index_usage_stats',	4,		'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_logger_index_usage_stats'),
			('dbo.usp_sqlwatch_logger_index_histogram',		5,		'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_logger_index_histogram'),
			
			('dbo.usp_sqlwatch_internal_add_database',		1,			'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_database'),
			('dbo.usp_sqlwatch_internal_add_job',			2,			'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_job'),
			('dbo.usp_sqlwatch_internal_add_performance_counter',	3,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_performance_counter'),
			('dbo.usp_sqlwatch_internal_add_master_file',			4,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_master_file'),
			('dbo.usp_sqlwatch_internal_add_wait_type',				5,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_wait_type'),
			('dbo.usp_sqlwatch_internal_add_memory_clerk',			6,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_memory_clerk'),
			('dbo.usp_sqlwatch_internal_add_table',					7,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_table')

/* create job and steps */
select @sql = replace(replace(convert(nvarchar(max),(select ' if (select name from msdb.dbo.sysjobs where name = ''' + job_name + ''') is null 
	begin
		exec msdb.dbo.sp_add_job @job_name=N''' + job_name + ''',  @category_name=N''' + @job_category + ''', @enabled=' + convert(char(1),job_enabled) + ',@description=''' + @job_description + ''';
		exec msdb.dbo.sp_add_jobserver @job_name=N''' + job_name + ''', @server_name = ''' + @server + ''';
		' + (select 
				' exec msdb.dbo.sp_add_jobstep @job_name=N''' + job_name + ''', @step_name=N''' + step_name + ''',@step_id= ' + convert(varchar(10),step_id) + ',@subsystem=N''' + step_subsystem + ''',@command=''' + replace(step_command,'''','''''') + ''',@on_success_action=' + case when ROW_NUMBER() over (partition by job_name order by step_id desc) = 1 then '1' else '3' end +', @on_fail_action=' + case when ROW_NUMBER() over (partition by job_name order by step_id desc) = 1 then '2' else '3' end + ', @database_name=''' + @database_name + ''''

			 from #steps 
			 where #steps.job_name = #jobs.job_name 
			 order by step_id asc
			 for xml path ('')) + '
		exec msdb.dbo.sp_update_job @job_name=N''' + job_name + ''', @start_step_id=1
		exec msdb.dbo.sp_add_jobschedule @job_name=N''' + job_name + ''', @name=N''' + job_name + ''', @enabled=1,@freq_type=' + convert(varchar(10),freq_type) + ',@freq_interval=' + convert(varchar(10),freq_interval) + ',@freq_subday_type=' + convert(varchar(10),freq_subday_type) + ',@freq_subday_interval=' + convert(varchar(10),freq_subday_interval) + ',@freq_relative_interval=' + convert(varchar(10),freq_relative_interval) + ',@freq_recurrence_factor=' + convert(varchar(10),freq_recurrence_factor) + ',@active_start_date=' + convert(varchar(10),active_start_date) + ',@active_end_date=' + convert(varchar(10),active_end_date) + ',@active_start_time=' + convert(varchar(10),active_start_time) + ',@active_end_time=' + convert(varchar(10),active_end_time) + ';
		Print ''Job ''''' + job_name + ''''' created.''
	end
else
	begin
		Print ''Job ''''' + job_name + ''''' not created becuase it already exists.''
	end;'
	from #jobs
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

Print '<# Scheduled tasks can only accept 261 characters long commands which is not enough for our PowerShell commands.
We are going to dump these into ps1 files and execute these files from the scheduler. Default location will be:
C:\SQLWATCHPS so feel free to change this before executing this script #>

$PSPath = "C:\SQLWATCHPS"

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
from #jobs j

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
		from #steps
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

		set @command = @command + char(10) + '$task=New-ScheduledTask -Action $actions -Trigger $trigger'
		set @command = @command + char(10) + 'Register-ScheduledTask "' + @task_name + '" -InputObject $task'
		
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
		set @command = @command + char(10) + '$task | Set-ScheduledTask'

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

end