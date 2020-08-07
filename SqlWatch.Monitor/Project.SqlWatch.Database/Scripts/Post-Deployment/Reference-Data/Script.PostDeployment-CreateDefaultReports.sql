/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
--------------------------------------------------------------------------------------
-- load default reports 
--------------------------------------------------------------------------------------
set identity_insert [dbo].[sqlwatch_config_report] on;
disable trigger dbo.trg_sqlwatch_config_report_updated_U on [dbo].[sqlwatch_config_report];

--Indexes with high fragmentation
exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -1
	,@report_title = 'Indexes with high fragmentation'
	,@report_description = 'Lisf ot indexes where the fragmentation is above 30% and page count greater than 1000. 
Index fragmentation can impact performance and should be minimum. You should be running index maintenance often. 
A very good and free index maintenance solution is Ola Hallengren''s Maintenance Solution'
	,@report_definition = 'SELECT [Table] = s.[name] +''.''+t.[name]
	,[Index] = i.NAME 
	,[Type] = index_type_desc
	,[Fragmentation] = convert(decimal(10,2),avg_fragmentation_in_percent)
	,[Records] = record_count
	,[Pages] = page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''SAMPLED'') ips
INNER JOIN sys.tables t on t.[object_id] = ips.[object_id]
INNER JOIN sys.schemas s on t.[schema_id] = s.[schema_id]
INNER JOIN sys.indexes i ON (ips.object_id = i.object_id) AND (ips.index_id = i.index_id)
WHERE avg_fragmentation_in_percent > 30
and page_count > 1000'
	,@report_definition_type = 'Table'
	,@report_action_id  = -1

--Agent Jobs failed in the last 5 minutes
exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -2
	,@report_title = 'Agent Job failures'
	,@report_description = 'List of SQL Server Agent Jobs that are enabled and have failed recently.'
	,@report_definition = ';with cte_failed_jobs as (
select 
	[Job] = sj.name,
	[Step] = sjs.step_name,
	[Message] = sjh.[message],
	[Run Time] = msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time)
FROM msdb.dbo.sysjobhistory sjh
inner join msdb.dbo.sysjobs sj 
	on sjh.job_id = sj.job_id
inner join msdb.dbo.sysjobsteps sjs
	on sjs.job_id = sj.job_id
	and sjh.step_id = sjs.step_id
where sjh.step_id > 0
    and msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time) >= isnull((
	select dateadd(second,-1,last_check_date)
	from [dbo].[sqlwatch_meta_check]
	where check_id = -1
	and sql_instance = @@SERVERNAME
),getdate())
	and sjh.run_status = 0
)
select @output=(select +
	''<h3>JOB: '' + c1.[Job] + ''</h3>'' +
	( select char(10) + ''<p>Step: '' + c2.[Step] + '' executed on: '' + convert(varchar(23),c2.[Run Time],121) + char(10) + ''<br>Message: <span style="color:red;">'' + c2.[Message] + ''</span></p>''
	from cte_failed_jobs c2
	where c1.[Job] = c2.[Job]
	order by [Run Time]
	for xml path(''''), type).value(''.'', ''nvarchar(MAX)'')
	 t
from cte_failed_jobs c1
group by c1.[Job]
for xml path(''''), type).value(''.'', ''nvarchar(MAX)'')'
	,@report_definition_type = 'Template'
	,@report_action_id  = -1

		--Blocked Processes in the last 5 minutes
exec [dbo].[usp_sqlwatch_config_add_report] 
		@report_id = -3
	,@report_title = 'Blocked Processes'
	,@report_description = 'List of blocking chains captured in the last minute.'
	,@report_definition = ';with cte_blocking as (
	SELECT *, rn=ROW_NUMBER() over (order by blocking_start_time)
	  FROM [dbo].[vw_sqlwatch_report_fact_xes_blockers] b
	  WHERE snapshot_time >= isnull((
	select last_check_date
	from [dbo].[sqlwatch_meta_check]
	where check_id = -2
	and sql_instance = @@SERVERNAME
	),getdate())
)
select @output=(select 
	''<hr>
<h3>Blocking SPID: '' + convert(varchar(10),c1.blocking_spid) + ''</h3>
Database Name: <b>['' + c1.[database_name] + '']</b>
<br>Blocking App: <b>'' + + c1.blocking_client_app_name + ''</b>
<br>Blocking Host: <b>'' + c1.blocking_client_hostname + ''</b>
<br>Blocking SQL: <table cellpadding="10" border=0 width="100%" style="background:#ddd; margin-top:1em;white-space: pre;"><tr><td><pre>'' + c1.blocking_sql + ''</pre></td></tr></table></p>
'' +
	( select char(10) + ''<table border=0 cellpadding="10" width="100%"><tr><td style="width:25px;"></td><td style="background:red;">
Blocking start time: '' + convert(varchar(23),c2.[blocking_start_time],121) + char(10) + ''
<br>Blocked SPID: <b>'' + convert(varchar(10),c2.blocked_spid) + ''</b>
<br>Blocked for: '' + convert(varchar,dateadd(ms,c2.blocking_duration_ms,0),114) + ''
<br>Blocked SQL: <table cellpadding="10" border=0 width="100%" style="background:#ddd; white-space: pre;"><tr><td><pre>'' + c2.[blocked_sql] + ''</pre></td></tr></table></td></tr></table>''
	from cte_blocking c2
	where c1.rn = c2.rn
	order by rn
	for xml path(''''), type).value(''.'', ''nvarchar(MAX)'')
	 t
from cte_blocking c1
group by c1.blocking_spid, c1.[database_name], c1.blocking_client_app_name, c1.blocking_client_hostname, c1.blocking_sql, rn
order by rn
for xml path(''''), type).value(''.'', ''nvarchar(MAX)'')'
	,@report_definition_type = 'Template'
	,@report_action_id  = -1


		--Disk utilisation report
exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -4
	,@report_title = 'Disk Utilisation Report'
	,@report_description = ''
	,@report_definition = 'select [Volume]=[volume_name]
,[Days Until Full] = [days_until_full]
,[Total Space] = [total_space_formatted]
,[Free Space] = [free_space_formatted] + '' ('' + [free_space_percentage_formatted] + '')''
,[Growth] = [growth_bytes_per_day_formatted]
from [dbo].[vw_sqlwatch_report_dim_os_volume]
where sql_instance = @@SERVERNAME'
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -5
	,@report_title = 'Backup Report'
	,@report_description = ''
	,@report_definition = 'SELECT 
     [Database] = d.name
	,[Recovery Model] = d.recovery_model_desc
    ,[Last Backup Date] = convert(varchar(23),max(bs.backup_finish_date),121)
    ,[Last FULL Backup] = convert(varchar(23),max(case when bs.type =''D'' then bs.backup_finish_date else null end),121)
    ,[Last DIFF Backup] = convert(varchar(23),max(case when bs.type =''I'' then bs.backup_finish_date else null end),121)
    ,[Last LOG Backup] =  case when d.recovery_model_desc = ''SIMPLE'' then ''N/A'' else convert(varchar(23),max(case when bs.type =''L'' then bs.backup_finish_date else null end),121) end	
	,[Minutes Since Last Log Backup] = convert(varchar(10),case when bs.type =''L'' then datediff(minute,(max(bs.backup_finish_Date)),getdate()) else null end)
    ,[Days Since Last Data Backup] = convert(varchar(10),datediff(day,(max(bs.backup_finish_Date)),getdate()))
from sys.databases d
left join msdb.dbo.backupset AS bs
	on bs.database_name = d.name
group by  
	  d.name
	, d.recovery_model_desc
	, bs.type
order by [Database]'
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -6
	,@report_title = 'Out of Date Log Backup Report'
	,@report_description = 'Report showing databases with out of date log backups.
This report can only be triggered from check as it contains check related variables.'
	,@report_definition = 'select * from (
	select 
		 [Database] = d.name
		,[Recovery Model] = d.recovery_model_desc
		,[Last LOG Backup] =  isnull(convert(varchar(23),max(bs.backup_finish_date),121),''--'')
		,[Minutes Since Last Log Backup] = isnull(convert(varchar(10),datediff(minute,(max(bs.backup_finish_Date)),getdate())),'''')
	from sys.databases d
	left join msdb.dbo.backupset AS bs
		on bs.database_name = d.name
		and bs.type = ''L''
	where d.recovery_model_desc <> ''SIMPLE''
	and d.name not in (''tempdb'')
	group by  
		  d.name
		, d.recovery_model_desc
		, bs.type
	) t
where (datediff(minute,replace([Last LOG Backup],''--'',''''),getdate()) {THRESHOLD})
and [Last LOG Backup] <> ''--'''
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -7
	,@report_title = 'Out of Date Data Backup Report'
	,@report_description = 'Report showing databases with out of date data backups.
This report can only be triggered from check as it contains check related variables.'
	,@report_definition = 'select * from (
	select 
		 [Database] = d.name
		,[Last Backup Date] = isnull(convert(varchar(23),max(bs.backup_finish_date),121),''--'')
		,[Days Since Last Data Backup] = isnull(convert(varchar(10),datediff(day,(max(bs.backup_finish_Date)),getdate())),'''')
	from sys.databases d
	left join msdb.dbo.backupset AS bs
		on bs.database_name = d.name
		and bs.type <> ''L''
	where d.name not in (''tempdb'')
	group by  
		  d.name
		, d.recovery_model_desc
		, bs.type
		) t
where (datediff(day,replace([Last Backup Date],''--'',''''),getdate()) {THRESHOLD})
and [Last Backup Date] <> ''--'''
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -8
	,@report_title = 'Missing Data Backup Report'
	,@report_description = 'Report showing databases with no data backups.
This report can only be triggered from check as it contains check related variables.'
	,@report_definition = 'select 
		 [Database] = d.name
		,[Last Backup Date] = isnull(convert(varchar(23),max(bs.backup_finish_date),121),''--'')
	from sys.databases d
	left join msdb.dbo.backupset AS bs
		on bs.database_name = d.name
		and bs.type <> ''L''
	where d.name not in (''tempdb'')
	and bs.backup_finish_date is null
	group by  
		  d.name
		, d.recovery_model_desc
		, bs.type'
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -9
	,@report_title = 'Missing Log Backup Report'
	,@report_description = 'Report showing databases with missing log backups.
This report can only be triggered from check as it contains check related variables.'
	,@report_definition = 'select 
		 [Database] = d.name
		,[Recovery Model] = d.recovery_model_desc
		,[Last LOG Backup] =  isnull(convert(varchar(23),max(bs.backup_finish_date),121),''--'')
	from sys.databases d
	left join msdb.dbo.backupset AS bs
		on bs.database_name = d.name
		and bs.type = ''L''
	where d.recovery_model_desc <> ''SIMPLE''
	and d.name not in (''tempdb'')
	and bs.backup_finish_date is null
	group by  
		  d.name
		, d.recovery_model_desc
		, bs.type'
	,@report_definition_type = 'Table'
	,@report_action_id  = -1;


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -10
	,@report_title = 'Long Open Transactions'
	,@report_description = 'Report showing open transactions and assosiated requests.
This report can only be triggered from check as it contains check related variables.'
	,@report_definition = 'with cte_open_tran as (
	select st.session_id, st.transaction_id, at.name, at.transaction_begin_time, s.login_name
	, r.start_time as request_start_time
	, r.[status] as requst_status
	, r.total_elapsed_time as request_total_elapsed_time
	, request_database_name = DB_NAME(r.database_id)
	, r.last_wait_type
	, t.[text]
	, [statement] = SUBSTRING(
					t.[text], r.statement_start_offset / 2, 
					(	CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH (t.[text]) 
							 ELSE r.statement_end_offset 
						END - r.statement_start_offset ) / 2 
				 )
	from sys.dm_tran_active_transactions at
	inner join sys.dm_tran_session_transactions st
		on at.transaction_id = st.transaction_id
	left join sys.dm_exec_requests r
		on r.session_id = st.session_id

	left join sys.dm_exec_sessions s
		on s.session_id = st.session_id
	cross apply sys.dm_exec_sql_text(r.sql_handle) AS t
	cross apply sys.dm_exec_query_plan(r.plan_handle) AS p

	where st.session_id <> @@SPID
	and st.session_id > 50
	and datediff(second,at.transaction_begin_time,getdate()) {THRESHOLD}
	and r.last_wait_type not in (''BROKER_RECEIVE_WAITFOR'')
)
select @output=(select ''<hr>
<h3>'' + c1.name + '' '' + convert(nvarchar(50),c1.transaction_id) + ''</h3>
<table>
<tr><td>Session ID</td><td>&nbsp;&nbsp;</td><td>'' + convert(nvarchar(10),c1.session_id) + ''</td></tr>
<tr><td>Session Login Name</td><td></td><td>'' + convert(nvarchar(255),c1.login_name) + ''</td></tr>
<tr><td>Transaction Databases</td><td></td><td><table>'' + (select ''<tr><td>'' + isnull(DB_NAME(c2.database_id),c2.database_id) + ''</td></tr>''
	from sys.dm_tran_database_transactions c2
	where c1.transaction_id = c2.transaction_id
	for xml path (''''), type).value(''.'', ''nvarchar(MAX)'') + ''</table></td></tr>
<tr><td>Transaction Begin Time</td><td></td><td>'' + convert(nvarchar(23),c1.transaction_begin_time,121) + ''</td></tr>
<tr><td>Request Start Time</td><td></td><td>'' + convert(varchar(23),request_start_time,121) + ''</td></tr>
<tr><td>Request Status</td><td></td><td>'' + requst_status + ''</td></tr>
<tr><td>Request Database</td><td></td><td>'' + request_database_name + ''</td></tr>
<tr><td>Request Last Wait Type</td><td></td><td>'' + last_wait_type + ''</td></tr>
<tr><td>Request Elspased Time</td><td></td><td>'' + convert(nvarchar, (request_total_elapsed_time / 1000 / 86400)) + '' '' + convert(nvarchar, DATEADD(ss, request_total_elapsed_time / 1000, 0), 108) + ''</td></tr></table>

<p>Request Statement:<p>
<table cellpadding="10" border=0 width="100%" style="background:#ddd; white-space: pre;"><tr><td><pre>'' + [statement] + ''</pre></td></tr></table>
<p>Request Batch:<p>
<table cellpadding="10" border=0 width="100%" style="background:#ddd; white-space: pre;"><tr><td><pre>'' + [text] + ''</pre></td></tr></table>''
from cte_open_tran c1
for xml path(''''), type).value(''.'', ''nvarchar(MAX)'')'
	,@report_definition_type = 'Template'
	,@report_action_id  = -1;


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -11
	,@report_title = 'SQLWATCH_Performance_Counters'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select mpc.sql_instance, mpc.[object_name], mpc.counter_name, pc.instance_name, pc.cntr_value_calculated, pc.snapshot_time
from [dbo].[sqlwatch_logger_perf_os_performance_counters] pc
inner join [dbo].[sqlwatch_meta_performance_counter] mpc
	on pc.performance_counter_id = mpc.performance_counter_id
	and mpc.sql_instance = pc.sql_instance
where snapshot_time > ''{REPORT_LAST_RUN_DATE}''
and snapshot_time <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -12
	,@report_title = 'SQLWATCH_OS_Volume'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select * from [dbo].[vw_sqlwatch_report_dim_os_volume]'
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'


exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -13
	,@report_title = 'SQLWATCH_Checks'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select d.[sql_instance], d.[snapshot_time], mc.check_name, d.[check_value], d.[check_status], d.status_change
from dbo.sqlwatch_logger_check d
	inner join [dbo].[sqlwatch_meta_check] mc
	on mc.sql_instance = d.sql_instance
	and mc.check_id = d.check_id
where snapshot_time > ''{REPORT_LAST_RUN_DATE}''
and snapshot_time <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -14
	,@report_title = 'SQLWATCH_File_Stats'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select [database_name],[file_name],[file_type_desc],[file_physical_name],[size_on_disk_bytes]
,[sql_instance],[num_of_reads_delta],[num_of_bytes_read_delta],[io_stall_read_ms_delta],[num_of_writes_delta]
,[num_of_bytes_written_delta],[io_stall_write_ms_delta],[size_on_disk_bytes_delta],[io_latency_read]
,[io_latency_write],[bytes_written_per_second],[bytes_read_per_second],[snapshot_time]
  from [dbo].[vw_sqlwatch_report_fact_perf_file_stats]
where snapshot_time > ''{REPORT_LAST_RUN_DATE}''
and snapshot_time <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -15
	,@report_title = 'SQLWATCH_Wait_Stats'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select [sql_instance],[wait_type],[waiting_tasks_count_delta],[wait_time_ms_delta]
,[max_wait_time_ms_delta],[signal_wait_time_ms_delta],[wait_category],[snapshot_time]
from [dbo].[vw_sqlwatch_report_fact_perf_os_wait_stats]
where snapshot_time > ''{REPORT_LAST_RUN_DATE}''
and snapshot_time <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -16
	,@report_title = 'SQLWATCH_Instance'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select sql_instance=[servername],[service_name],[local_net_address],[local_tcp_port],[utc_offset_minutes],[sql_version] from [dbo].[sqlwatch_meta_server]'
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'



exec [dbo].[usp_sqlwatch_config_add_report] 
	 @report_id = -17
	,@report_title = 'SQLWATCH_Agent_History'
	,@report_description = 'Extract for Azure Log Monitor'
	,@report_definition = 'select [sql_instance],[job_name],[step_name],[run_duration_s],[run_date],[run_status_desc],[end_date],[snapshot_time]
from [dbo].[vw_sqlwatch_report_fact_agent_job_history]
where run_date > ''{REPORT_LAST_RUN_DATE}''
and run_date <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
	,@report_definition_type = 'Query'
	,@report_action_id  = -16
	,@report_batch_id = 'AzureLogMonitor-1'


/*	Azure adds a lot of overhead to the data we push and seems like normalisation on local side makes very little difference to the overall row size.
	For example, the below denormalised and normalised performance counters:

	SQLWATCH_Performance_Counters_CL			Table Entries: 800	Table Size: 693.033 KiB		Size per Entry: 887.08 B	==> 2.9939GB per Month
	SQLWATCH_Performance_Counters_Data_CL		Table Entries: 800	Table Size: 631.559 KiB		Size per Entry: 808.40 B	==> 2.7283GB per Month

	But with the denormalised set we are not having to send meta data every so often and we are not having to join in Azure Log which also saves
	on the number of transactions
*/

--exec [dbo].[usp_sqlwatch_user_add_report] 
--	 @report_id = -18
--	,@report_title = 'SQLWATCH_Performance_Counters_Data'
--	,@report_description = 'Extract for Azure Log Monitor'
--	,@report_definition = 'select [performance_counter_id],[instance_name],[snapshot_time],[sql_instance],[cntr_value_calculated]
--from [dbo].[sqlwatch_logger_perf_os_performance_counters]
--where [snapshot_time] > ''{REPORT_LAST_RUN_DATE}''
--and [snapshot_time] <= ''{REPORT_CURRENT_RUN_DATE_UTC}'''
--	,@report_definition_type = 'Query'
--	,@report_action_id  = -16
--	,@report_batch_id = 'AzureLogMonitor-1'


set identity_insert [dbo].[sqlwatch_config_report] off;
enable trigger dbo.trg_sqlwatch_config_report_updated_U on [dbo].[sqlwatch_config_report];