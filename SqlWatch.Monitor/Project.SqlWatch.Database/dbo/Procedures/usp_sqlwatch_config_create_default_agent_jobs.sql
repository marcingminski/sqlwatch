CREATE PROCEDURE [dbo].[usp_sqlwatch_config_create_default_agent_jobs]
	@remove_existing bit = 0,
	@print_WTS_command bit = 0,
	@job_owner sysname = null
AS

set nocount on;

-- check if agent is running and quit of not.
-- if the agent isnt running or if we're in express edition we dont want to raise errors just a gentle warning
-- if we are in the express edition we will be able to run collection via broker

if [dbo].[ufn_sqlwatch_get_agent_status]() = 0
	begin
		print 'SQL Agent is not running. SQLWATCH relies on Agent to collect performance data.
		The database will be deployed but you will have to deploy jobs manually once you have enabled SQL Agent.
		You can run "exec [dbo].[usp_sqlwatch_config_create_default_agent_jobs]" to create default jobs.
		If you are running Express Edition you will be able to invoke collection via broker'
		return;
	end

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
	job_description nvarchar(2000),
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
	step_id int identity(1,1),
	job_name sysname,
	step_subsystem sysname,
	step_command varchar(max)
	)

declare @enabled tinyint = 1

/* job definition must be in the right order as they are executed as part of deployment */
insert into ##sqlwatch_jobs
			( job_name,							job_description,	freq_type,	freq_interval,	freq_subday_type,	freq_subday_interval,	freq_relative_interval, freq_recurrence_factor	,	active_start_time,	job_enabled )
	values	
			 ('SQLWATCH-DISK-UTILISATION',		'This job requires access to PowerShell and WMI to gather OS disk utilistaion. This is not something we can do via T-SQL without hacking xp_cmdshell.',
																	4,			1,				8,					1,						0,						1,							437,				1)
			,('SQLWATCH-PROCESS-ACTIONS',		'This job has no schedule and its invoked on demand by SQLWATCH. Do not add schedule and do not disable this job otherwise the queue will fill up if actions are enabled. To stop processing actions, disable individual actions in the config table.',				
																	null,		null,			null,				null,					null,					null,						null,				1)
			,('SQLWATCH-REPORT-AZMONITOR',		null,				4,			1,				4,					10,						0,						1,							21,					1)

/* step definition */

insert into ##sqlwatch_steps (step_name, job_name, step_subsystem, step_command) 
	values
			/* step name											job_name							subsystem,	command */
			('dbo.usp_sqlwatch_internal_process_reports',			'SQLWATCH-REPORT-AZMONITOR',		'TSQL',		'exec dbo.usp_sqlwatch_internal_process_reports @report_batch_id = ''AzureLogMonitor-1'''),
			('Process Actions',										'SQLWATCH-PROCESS-ACTIONS',			'PowerShell',N'
$queueitem = "x";

while ($queueitem -ne $null) 
{
    $queueitem = Invoke-Sqlcmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -MaxCharLength 2147483647 -Query "
		waitfor (
			receive top (1)
				conversation_handle,
				CAST(message_body AS xml) as message_body,
				message_type_name
			from [dbo].[sqlwatch_actions]
		), timeout = 300000;
    ";

    if ($queueitem -ne $null) 
    {
        if ($queueitem.message_type_name -like "mtype_sqlwatch_action*")
        {
            [xml]$message_body_xml = $queueitem.message_body;

            if ( $message_body_xml.action.data.row.action_exec_type -eq "PowerShell" )
            {
                $output = Invoke-Expression $message_body_xml.action.data.row.action_exec -ErrorAction "Stop" ;

                ##TODO TO DO we will compare the actual output with expected output here
            }
            elseif ( $message_body_xml.action.data.row.action_exec_type -eq "T-SQL" )
            {
                $output = Invoke-Sqlcmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -MaxCharLength 2147483647 -Query $message_body_xml.action.data.row.action_exec;
            }
        }
        else 
        {
            Invoke-Sqlcmd -ServerInstance SQL-2 -Database SQLWATCH_5_0 -Query "end conversation ''$queueitem.conversation_handle'';"
        }
    }
};
'),

			('Get-WMIObject Win32_Volume',		'SQLWATCH-DISK-UTILISATION',	'PowerShell', N'
$SnapshotTime = (Get-Date).ToUniversalTime();
$xml = "<CollectionSnapshot>`n";
$xml += "<snapshot_header>`n";
$xml += "<row snapshot_time=`"$SnapshotTime`" snapshot_type_id=`"17`" sql_instance=`"' + @server + '`" />\n";
$xml += "</snapshot_header>`n";
$xml += "<disk_space_usage>`n";

Get-WMIObject Win32_Volume | ?{$_.DriveType -eq 3 -And $_.Name -notlike "\\?\Volume*" } | %{

    $VolumeName = $_.Name
    $FreeSpace = $_.Freespace
    $Capacity = $_.Capacity
    $VolumeLabel = $_.Label
    $FileSystem = $_.Filesystem
    $BlockSize = $_.BlockSize

    $xml += "<row volume_name=`"$VolumeName`" freespace=`"$FreeSpace`" capacity=`"$Capacity`" label=`"$VolumeLabel`" filesystem=`"$FileSystem`" blocksize=`"$BlockSize`" />\n";
}

$xml += "</disk_space_usage>`n";
$xml += "</CollectionSnapshot>`n";


$sql = "declare @cid uniqueidentifier;
exec [dbo].[usp_sqlwatch_internal_broker_dialog_new] @cid = @cid output;

DECLARE @xml XML = cast (''$xml'' as xml); SEND ON CONVERSATION @cid MESSAGE TYPE [mtype_sqlwatch_collector] (@xml);
"

Invoke-Sqlcmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -MaxCharLength 2147483647 -Query $sql			
			')


	exec [dbo].[usp_sqlwatch_internal_create_agent_job]
		@print_WTS_command = @print_WTS_command, @job_owner = @job_owner;