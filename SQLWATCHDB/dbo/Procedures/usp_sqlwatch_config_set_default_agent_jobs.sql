CREATE PROCEDURE [dbo].[usp_sqlwatch_config_set_default_agent_jobs]
	@remove_existing bit = 0
AS

/* create jobs */
declare @sql varchar(max)
declare @job_description nvarchar(255) = 'https://sqlwatch.io'
declare @job_category nvarchar(255) = 'Data Collector'
declare @database_name sysname = '$(DatabaseName)'
declare @command nvarchar(4000)

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
set @enabled = case when object_id('master.dbo.sp_whoisactive') is not null then 1 else 0 end

/* job definition */
insert into #jobs

			/* JOB_NAME                 freq:	type,	interval,	subday_type,	subday_intrval, relative_interval,	recurrence_factor,	start_date, end_date, start_time,	end_time,	enabled */
	values	('SQLWATCH-LOGGER-WHOISACTIVE',		4,		1,			2,				15,				0,					0,					20180101,	99991231, 0,			235959,		@enabled),
			('SQLWATCH-LOGGER-PERFORMANCE',		4,		1,			4,				1,				0,					1,					20180101,	99991231, 12,			235959,		1),
			('SQLWATCH-INTERNAL-RETENTION',		4,		1,			8,				1,				0,					1,					20180101,	99991231, 20,			235959,		1),
			('SQLWATCH-LOGGER-DISK-UTILISATION',4,		1,			8,				1,				0,					1,					20180101,	99991231, 437,			235959,		1),
			('SQLWATCH-LOGGER-INDEXES',			4,		1,			8,				6,				0,					1,					20180101,	99991231, 420,			235959,		1),
			('SQLWATCH-INTERNAL-META-CONFIG',	4,		1,			8,				1,				0,					1,					20180101,	99991231, 26,			235959,		1),
			('SQLWATCH-LOGGER-AGENT-HISTORY',	4,		1,			4,				10,				0,					1,					20180101,	99991231, 0,			235959,		1),
			('SQLWATCH-ALERTS',					4,		1,			4,				1,				0,					1,					20180101,	99991231, 45,			235959,		1)


			

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

			('dbo.usp_sqlwatch_internal_process_checks',1,			'SQLWATCH-ALERTS',					'TSQL',		'exec dbo.usp_sqlwatch_internal_process_checks'),
			('Send Message',							2,			'SQLWATCH-ALERTS',					'PowerShell','
$output = "x"
while ($output -ne $null) { 
	$output = Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query "set xact_abort on
	begin tran
		;with cte_get_message as (
		  select top 1 *
		  from [dbo].[sqlwatch_meta_alert_notify_queue]
		  where send_status = 0
		  order by notify_timestamp
		)
		update cte_get_message
			set send_status = 1
			output deleted.[message_payload], deleted.target_type, deleted.notify_id
			where send_status = 0
	commit tran"

	$status = ""
	$notify_id = $output.notify_id
    $operation = ""
	$ErrorOutput = ""
	
	if ( $output -ne $null) {
		if ( $output.target_type -eq "sp_send_dbmail" ) {
			$status = Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query $output.message_payload
            if ($status.error -eq 0) {
                $operation = "delete"
            } else {
                $operation = "update"
			}
		}

		if ( $output.target_type -eq "Pushover" ) {
			$status = Invoke-Expression $output.message_payload
			if ($status.status -eq "1") {
				$operation = "delete"  
			} else {
				$operation = "update"
			}
		}

		if ( $output.target_type -eq "Send-MailMessage" ) {
		    Invoke-Expression $output.message_payload
			$ErrorOutput = $Error[0].Exception.Message
            if ($ErrorOutput -ne "") {
				$operation = "update"
            } else {
                $operation = "delete"
			}
		}

       if ($operation -eq "delete") {
 			$query = "delete from [dbo].[sqlwatch_meta_alert_notify_queue] where notify_id = $notify_id"
        } else {
			$query = "update [dbo].[sqlwatch_meta_alert_notify_queue] set send_status = 2, [send_error_message] = ''$ErrorOutput'' where notify_id = $notify_id"   
        }
		Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query $query
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
			
			('dbo.usp_sqlwatch_internal_add_database',		1,			'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_database'),
			('dbo.usp_sqlwatch_internal_add_job',			2,			'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_job'),
			('dbo.usp_sqlwatch_internal_add_performance_counter',	3,	'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_performance_counter'),
			('dbo.usp_sqlwatch_internal_add_master_file',			4,	'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_master_file'),
			('dbo.usp_sqlwatch_internal_add_wait_type',				5,	'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_wait_type'),
			('dbo.usp_sqlwatch_internal_add_memory_clerk',			6,	'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_memory_clerk'),
			('dbo.usp_sqlwatch_internal_add_table',					7,	'SQLWATCH-INTERNAL-META-CONFIG','TSQL', 'exec dbo.usp_sqlwatch_internal_add_table')

	
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

print @sql
exec (@sql)
