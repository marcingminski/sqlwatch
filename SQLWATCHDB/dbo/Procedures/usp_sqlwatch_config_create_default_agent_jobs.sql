CREATE PROCEDURE [dbo].[usp_sqlwatch_config_create_default_agent_jobs]
	@remove_existing bit = 0,
	@print_WTS_command bit = 0,
	@job_owner sysname = null
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
	1.2		2020-01-29	- Marcin Gminski, add job owner
-------------------------------------------------------------------------------------------------------------------
*/
set nocount on;

/* create jobs */
declare @sql varchar(max)

declare @server nvarchar(255)
set @server = @@SERVERNAME


set @sql = ''
if @remove_existing = 1
	begin
		select @sql = @sql + 'exec msdb.dbo.sp_delete_job @job_id=N''' + convert(varchar(255),job_id) + ''';' 
		from msdb.dbo.sysjobs
where name like 'SQLWATCH-%'
and name not like 'SQLWATCH-REPOSITORY-%'
		exec (@sql)
		Print 'Existing default SQLWATCH jobs deleted'
	end

set @sql = ''
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

declare @enabled tinyint = 1
set @enabled = case when object_id('master.dbo.sp_whoisactive') is not null or object_id('dbo.sp_whoisactive') is not null then 1 else 0 end

/* job definition must be in the right order as they are executed as part of deployment */
insert into ##sqlwatch_jobs 
			( job_name,							freq_type,	freq_interval,	freq_subday_type,	freq_subday_interval,	freq_relative_interval, freq_recurrence_factor,		active_start_date,	active_end_date,	active_start_time,	active_end_time,	job_enabled )
	values	
			('SQLWATCH-INTERNAL-CONFIG',		4,			1,				8,					1,						0,						1,							20180101,			99991231,			26,					235959,				1),

			('SQLWATCH-LOGGER-PERFORMANCE',		4,			1,				4,					1,						0,						1,							20180101,			99991231,			12,					235959,				1),
			('SQLWATCH-LOGGER-DISK-UTILISATION',4,			1,				8,					1,						0,						1,							20180101,			99991231,			437,				235959,				1),
			('SQLWATCH-LOGGER-INDEXES',			4,			1,				8,					6,						0,						1,							20180101,			99991231,			420,				235959,				1),
			('SQLWATCH-LOGGER-AGENT-HISTORY',	4,			1,				4,					10,						0,						1,							20180101,			99991231,			0,					235959,				1),

			('SQLWATCH-INTERNAL-RETENTION',		4,			1,				8,					1,						0,						1,							20180101,			99991231,			20,					235959,				1),
			('SQLWATCH-INTERNAL-TRENDS',		4,			1,				4,					60,						0,						1,							20180101,			99991231,			150,				235959,				1),

			('SQLWATCH-INTERNAL-ACTIONS',		4,			1,				2,					15,						0,						1,							20180101,			99991231,			2,					235959,				1),

			('SQLWATCH-REPORT-AZMONITOR',		4,			1,				4,					10,						0,						1,							20180101,			99991231,			21,					235959,				1),
			('SQLWATCH-LOGGER-WHOISACTIVE',		4,			1,				2,					15,						0,						0,							20180101,			99991231,			0,					235959,				@enabled),

			('SQLWATCH-INTERNAL-CHECKS',		4,			1,				4,					1,						0,						1,							20180101,			99991231,			43,					235959,				1),
			('SQLWATCH-LOGGER-SYSCONFIG',		4,			1,				1,					1,						0,						1,							20180101,			99991231,			0,					235959,				1)

			--('SQLWATCH-USER-REPORTS',			4,		1,			1,				0,				0,					1,					20180101,	99991231, 80000,		235959,		1)


/* step definition */

/*  Normally, the SQLWATCH-INTERNAL-META-CONFIG runs any metadata config procedures that collect reference data every hour. by reference data
	we mean list of databases, tables, jobs, indexes etc. this is to reduce load during more frequent collectors such as the performance collector.
	For obvious reasons, we would not want to collect list of tables every minute as that would be pointless however, in case of less frequent jobs such as disk collector 
	and index collection, or those more time consuming and resource heavy, by exception, we will run meta data collection part of the data collector job rather than the standard meta-config job 
	SQLWATCH tries to be as lightweight as possible and will not collect any data unles required.
*/

insert into ##sqlwatch_steps
			/* step name								step_id,	job_name							subsystem,	command */
	values	('dbo.usp_sqlwatch_logger_whoisactive',		1,			'SQLWATCH-LOGGER-WHOISACTIVE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_whoisactive'),

			('dbo.usp_sqlwatch_logger_performance',		1,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_performance'),
			('dbo.usp_sqlwatch_logger_xes_waits',		2,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_waits'),
			('dbo.usp_sqlwatch_logger_xes_blockers',	3,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_blockers'),
			('dbo.usp_sqlwatch_logger_xes_diagnostics',	4,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_diagnostics'),
			('dbo.usp_sqlwatch_logger_xes_long_queries',5,			'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL',		'exec dbo.usp_sqlwatch_logger_xes_long_queries'),

			('dbo.usp_sqlwatch_trend_perf_os_performance_counters',1,'SQLWATCH-INTERNAL-TRENDS',		'TSQL',		'exec dbo.usp_sqlwatch_trend_perf_os_performance_counters'),

			--('dbo.usp_sqlwatch_internal_process_reports',1,			'SQLWATCH-USER-REPORTS',			'TSQL',		'exec dbo.usp_sqlwatch_internal_process_reports @report_batch_id = 1'),

			('dbo.usp_sqlwatch_internal_process_checks',1,			'SQLWATCH-INTERNAL-CHECKS',			'TSQL',		'exec dbo.usp_sqlwatch_internal_process_checks'),
			('dbo.usp_sqlwatch_internal_process_reports',1,			'SQLWATCH-REPORT-AZMONITOR',		'TSQL',		'exec dbo.usp_sqlwatch_internal_process_reports @report_batch_id = ''AzureLogMonitor-1'''),


			('Process Actions',							1,			'SQLWATCH-INTERNAL-ACTIONS',		'PowerShell','
$output = "x"
while ($output -ne $null) { 
	$output = Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -MaxCharLength 2147483647 -Query "exec [dbo].[usp_sqlwatch_internal_action_queue_get_next]"

	$status = ""
	$queue_item_id = $output.queue_item_id
    $operation = ""
	$ErrorOutput = ""
	$MsgType = "OK"
	
	if ( $output -ne $null) {
		if ( $output.action_exec_type -eq "T-SQL" ) {
			try {
				$ErrorOutput = Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -ErrorAction "Stop" -Query $output.action_exec -MaxCharLength 2147483647
			}
			catch {
				$ErrorOutput = $error[0] -replace "''", "''''"
				$MsgType = "ERROR"
			}
		}

		if ( $output.action_exec_type -eq "PowerShell" ) {
			try {
				$ErrorOutput = Invoke-Expression $output.action_exec -ErrorAction "Stop" 
			}
			catch {
				$ErrorOutput = $_.Exception.Message -replace "''", "''''"
				$MsgType = "ERROR"
			}
		}
		Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -ErrorAction "Stop" -Query "exec [dbo].[usp_sqlwatch_internal_action_queue_update]
					@queue_item_id = $queue_item_id,
					@error = ''$ErrorOutput'',
					@exec_status = ''$MsgType''"
	}
}'),
			
			('dbo.usp_sqlwatch_logger_agent_job_history', 1,		'SQLWATCH-LOGGER-AGENT-HISTORY',	'TSQL',		'exec dbo.usp_sqlwatch_logger_agent_job_history'),

			('dbo.usp_sqlwatch_internal_retention',		1,			'SQLWATCH-INTERNAL-RETENTION',		'TSQL',		'exec dbo.usp_sqlwatch_internal_retention'),
			('dbo.usp_sqlwatch_internal_purge_deleted_items',2,		'SQLWATCH-INTERNAL-RETENTION',		'TSQL',		'exec dbo.usp_sqlwatch_internal_purge_deleted_items'),

			('dbo.usp_sqlwatch_logger_disk_utilisation',1,			'SQLWATCH-LOGGER-DISK-UTILISATION',	'TSQL',		'exec dbo.usp_sqlwatch_logger_disk_utilisation'),
			('dbo.usp_sqlwatch_logger_disk_utilisation_table',3,	'SQLWATCH-LOGGER-DISK-UTILISATION', 'TSQL',		'exec dbo.usp_sqlwatch_logger_disk_utilisation_table'),

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
			('dbo.usp_sqlwatch_internal_add_table',					7,	'SQLWATCH-INTERNAL-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_table'),
			
			('dbo.usp_sqlwatch_internal_add_system_configuration',	1,	'SQLWATCH-LOGGER-SYSCONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_system_configuration'),
			('dbo.usp_sqlwatch_logger_system_configuration',	    2,	'SQLWATCH-LOGGER-SYSCONFIG','TSQL', 'exec dbo.usp_sqlwatch_logger_system_configuration')


	exec [dbo].[usp_sqlwatch_internal_create_agent_job]
		@print_WTS_command = @print_WTS_command, @job_owner = @job_owner

