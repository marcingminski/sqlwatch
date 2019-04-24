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


/* Since version beta 6 these objects are no longer required. They have been removed from the Project however,
	as SQLWATCH can be installed in the existing database the dacpac deployment does not drop objects not in the Project.
	This is to prevent removing any non-SQLWATCH objects. For this reason we have to handle objects removal manually */

	if object_id ('[dbo].[vw_sql_perf_mon_rep_mem_proc]') is not null
		drop view [dbo].[vw_sql_perf_mon_rep_mem_proc]

	if object_id ('[dbo].[vw_sql_perf_mon_rep_perf_counter]') is not null
		drop view [dbo].[vw_sql_perf_mon_rep_perf_counter]

	if object_id ('[dbo].[vw_sql_perf_mon_time_intervals]') is not null
		drop view [dbo].[vw_sql_perf_mon_time_intervals]

	if object_id ('[dbo].[vw_sql_perf_mon_wait_stats_categorised]') is not null
		drop view [dbo].[vw_sql_perf_mon_wait_stats_categorised]

	if object_id ('[dbo].[sql_perf_mon_config_report_time_interval]') is not null
		drop table [dbo].[sql_perf_mon_config_report_time_interval]

	if object_id ('[dbo].[sql_perf_mon_config_wait_stats]') is not null
		drop table [dbo].[sql_perf_mon_config_wait_stats]

	if object_id ('[dbo].[sql_perf_mon_config_who_is_active_age]') is not null
		drop table [dbo].[sql_perf_mon_config_who_is_active_age]

	if object_id ('[dbo].[sql_perf_mon_who_is_active_tmp]') is not null
		drop table [dbo].[sql_perf_mon_who_is_active_tmp]


/* add local instance to server config so we can satify relations */
merge dbo.sqlwatch_config_sql_instance as target
using (select sql_instance = @@SERVERNAME) as source
on target.sql_instance = source.sql_instance
when not matched then
	insert (sql_instance)
	values (@@SERVERNAME);

--/* start XE sessions */
--declare @sqlstmt varchar(4000) = ''

--select @sqlstmt = @sqlstmt + 'alter event session [' + es.name + '] on server state = start' + char(10) 
--from sys.server_event_sessions es
--left join sys.dm_xe_sessions xs ON xs.name = es.name
--where es.name in ('--SQLWATCH_workload','SQLWATCH_waits','SQLWATCH_blockers') --not starting worklaod capture, leaving this to individuals to decide if they want to capture long queries
--and xs.name is null

--exec (@sqlstmt)


--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------
/*	databases with create_date = '1970-01-01' are from previous 
versions of SQLWATCH and we will now update create_date to the actual
create_date (this will only apply to upgrades) */
update swd
	set [database_create_date] = db.[create_date]
from [dbo].[sqlwatch_meta_database] swd
inner join sys.databases db
	on db.[name] = swd.[database_name] collate database_default
	and swd.[database_create_date] = '1970-01-01'
	and swd.sql_instance = @@SERVERNAME

/* now add new databases */
exec [dbo].[usp_sqlwatch_internal_add_database]

--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------
if (select count(*) from [dbo].[sqlwatch_meta_server]) = 0
	begin
		insert into dbo.[sqlwatch_meta_server] 
		select convert(sysname,SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
			, convert(sysname,@@SERVERNAME), convert(sysname,@@SERVICENAME), convert(varchar(50),local_net_address), convert(varchar(50),local_tcp_port)
		from sys.dm_exec_connections where session_id = @@spid
	end

--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------
create table #sql_perf_mon_config_perf_counters (
	[object_name] nvarchar(256) not null,
	[instance_name] nvarchar(256) not null,
	[counter_name] nvarchar(256) not null,
	[base_counter_name] nvarchar(256) null,
	[collect] bit null,
	constraint tmp_pk_sql_perf_mon_config_perf_counters primary key (
		[object_name] , [instance_name], [counter_name]
	)
)
create nonclustered index tmp_idx_sql_perf_mon_perf_counters_types on #sql_perf_mon_config_perf_counters ([collect]) include ([object_name],[instance_name],[counter_name],[base_counter_name])

/* based on https://blogs.msdn.microsoft.com/dfurman/2015/04/02/collecting-performance-counter-values-from-a-sql-azure-database/ */	
insert into #sql_perf_mon_config_perf_counters([collect],[object_name],[counter_name], [instance_name],[base_counter_name]) 
	values
		 (0,'Access Methods','Forwarded Records/sec','',NULL)
		,(1,'Access Methods','Full Scans/sec','',NULL)
		,(1,'Access Methods','Page Splits/sec','',NULL)
		,(1,'Access Methods','Pages Allocated/sec','',NULL)
		,(0,'Access Methods','Table Lock Escalations/sec','',NULL)
		,(1,'Access Methods','Index Searches/sec','',NULL)
		,(1,'Access Methods','Page Deallocations/sec','',NULL)
		,(1,'Access Methods','Page compression attempts/sec','',NULL)
		,(1,'Access Methods','Pages compressed/sec','',NULL)
		,(0,'Availability Replica','Bytes Received from Replica/sec','_Total',NULL)
		,(0,'Availability Replica','Bytes Sent to Replica/sec','_Total',NULL)
		,(0,'Batch Resp Statistics','Batches >=000000ms & <000001ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000001ms & <000002ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000002ms & <000005ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000005ms & <000010ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000010ms & <000020ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000020ms & <000050ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000050ms & <000100ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000100ms & <000200ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000200ms & <000500ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000500ms & <001000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=001000ms & <002000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=002000ms & <005000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=005000ms & <010000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=010000ms & <020000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=020000ms & <050000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=050000ms & <100000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=100000ms','CPU Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000000ms & <000001ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000001ms & <000002ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000002ms & <000005ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000005ms & <000010ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000010ms & <000020ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000020ms & <000050ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000050ms & <000100ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000100ms & <000200ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000200ms & <000500ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000500ms & <001000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=001000ms & <002000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=002000ms & <005000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=005000ms & <010000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=010000ms & <020000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=020000ms & <050000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=050000ms & <100000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=100000ms','CPU Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000010ms & <000020ms','Elappsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000000ms & <000001ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000001ms & <000002ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000002ms & <000005ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000005ms & <000010ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000020ms & <000050ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000050ms & <000100ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000100ms & <000200ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000200ms & <000500ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000500ms & <001000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=001000ms & <002000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=002000ms & <005000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=005000ms & <010000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=010000ms & <020000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=020000ms & <050000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=050000ms & <100000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=100000ms','Elapsed Time:Requests',NULL)
		,(0,'Batch Resp Statistics','Batches >=000000ms & <000001ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000001ms & <000002ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000002ms & <000005ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000005ms & <000010ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000010ms & <000020ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000020ms & <000050ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000050ms & <000100ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000100ms & <000200ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000200ms & <000500ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=000500ms & <001000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=001000ms & <002000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=002000ms & <005000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=005000ms & <010000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=010000ms & <020000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=020000ms & <050000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=050000ms & <100000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Batch Resp Statistics','Batches >=100000ms','Elapsed Time:Total(ms)',NULL)
		,(0,'Buffer Manager','Background writer pages/sec','',NULL)
		,(1,'Buffer Manager','Buffer cache hit ratio','','Buffer cache hit ratio base ')
		,(1,'Buffer Manager','Buffer cache hit ratio base','',NULL)
		,(1,'Buffer Manager','Checkpoint pages/sec','',NULL)
		,(1,'Buffer Manager','Lazy writes/sec','',NULL)
		,(1,'Buffer Manager','Page reads/sec','',NULL)
		,(1,'Buffer Manager','Readahead pages/sec','',NULL)
		,(1,'Buffer Manager','Page lookups/sec','',NULL)
		,(1,'Buffer Manager','Workfiles Created/sec','',NULL)
		,(1,'Buffer Manager','Worktables Created/sec','',NULL)
		,(1,'Buffer Manager','Free list stalls/sec','',NULL)
		,(1,'Buffer Manager','Page writes/sec','',NULL)
		,(1,'Buffer Node','Page life expectancy','000',NULL)
		,(0,'Database Replica','File Bytes Received/sec','_Total',NULL)
		,(0,'Database Replica','Log Bytes Received/sec','_Total',NULL)
		,(0,'Database Replica','Log remaining for undo','_Total',NULL)
		,(0,'Database Replica','Log Send Queue','_Total',NULL)
		,(0,'Database Replica','Mirrored Write Transactions/sec','_Total',NULL)
		,(0,'Database Replica','Recovery Queue','_Total',NULL)
		,(0,'Database Replica','Redo blocked/sec','_Total',NULL)
		,(0,'Database Replica','Redo Bytes Remaining','_Total',NULL)
		,(0,'Database Replica','Redone Bytes/sec','_Total',NULL)
		,(0,'Database Replica','Total Log requiring undo','_Total',NULL)
		,(0,'Database Replica','Transaction Delay','_Total',NULL)
		,(0,'Databases','Checkpoint duration','_Total',NULL)
		,(0,'Databases','Group Commit Time/sec','_Total',NULL)
		,(0,'Databases','Log Bytes Flushed/sec','_Total',NULL)
		,(0,'Databases','Log Flush Waits/sec','_Total',NULL)
		,(1,'Databases','Log Flushes/sec','_Total',NULL)
		,(1,'Databases','Log Growths','_Total',NULL)
		,(0,'Databases','Percent Log Used','<* !_Total>',NULL)
		,(1,'Databases','Transactions/sec','<* !_Total>',NULL)
		,(1,'Databases','Write Transactions/sec','_Total',NULL)
		,(1,'Databases','Active Transactions','_Total',NULL)
		,(1,'Databases','Log Truncations','_Total',NULL)
		,(1,'Databases','Log Shrinks','_Total',NULL)
		,(0,'Databases','Checkpoint duration','tempdb',NULL)
		,(0,'Databases','Group Commit Time/sec','tempdb',NULL)
		,(0,'Databases','Log Bytes Flushed/sec','tempdb',NULL)
		,(0,'Databases','Log Flush Waits/sec','tempdb',NULL)
		,(0,'Databases','Log Flushes/sec','tempdb',NULL)
		,(0,'Databases','Log Growths','tempdb',NULL)
		,(0,'Databases','Percent Log Used','tempdb',NULL)
		,(0,'Databases','Transactions/sec','tempdb',NULL)
		,(0,'Databases','Write Transactions/sec','tempdb',NULL)
		,(1,'General Statistics','Active Temp Tables','',NULL)
		,(0,'General Statistics','Logical Connections','',NULL)
		,(1,'General Statistics','Logins/sec','',NULL)
		,(0,'General Statistics','Logouts/sec','',NULL)
		,(1,'General Statistics','Processes blocked','',NULL)
		,(1,'General Statistics','User Connections','',NULL)
		,(1,'General Statistics','Temp Tables Creation Rate','',NULL)
		,(0,'HTTP Storage','Avg. Bytes/Read','<* !_Total>','Avg. Bytes/Read BASE ')
		,(0,'HTTP Storage','Avg. Bytes/Read BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. Bytes/Transfer','<* !_Total>','Avg. Bytes/Transfer BASE ')
		,(0,'HTTP Storage','Avg. Bytes/Transfer BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. Bytes/Write','<* !_Total>','Avg. Bytes/Write BASE ')
		,(0,'HTTP Storage','Avg. Bytes/Write BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. microsec/Read','<* !_Total>','Avg. microsec/Read BASE ')
		,(0,'HTTP Storage','Avg. microsec/Read BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. microsec/Read Comp','<* !_Total>','Avg. microsec/Read Comp BASE ')
		,(0,'HTTP Storage','Avg. microsec/Read Comp BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. microsec/Transfer','<* !_Total>','Avg. microsec/Transfer BASE ')
		,(0,'HTTP Storage','Avg. microsec/Transfer BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. microsec/Write','<* !_Total>','Avg. microsec/Write BASE ')
		,(0,'HTTP Storage','Avg. microsec/Write BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','Avg. microsec/Write Comp','<* !_Total>','Avg. microsec/Write Comp BASE ')
		,(0,'HTTP Storage','Avg. microsec/Write Comp BASE','<* !_Total>',NULL)
		,(0,'HTTP Storage','HTTP Storage IO failed/sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','HTTP Storage IO retry/sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Outstanding HTTP Storage IO','<* !_Total>',NULL)
		,(0,'HTTP Storage','Read Bytes/Sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Reads/Sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Total Bytes/Sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Transfers/Sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Write Bytes/Sec','<* !_Total>',NULL)
		,(0,'HTTP Storage','Writes/Sec','<* !_Total>',NULL)
		,(1,'Latches','Latch Waits/sec','',NULL)
		,(1,'Locks','Average Wait Time (ms)','_Total','Average Wait Time Base ')
		,(1,'Locks','Average Wait Time Base','_Total',NULL)
		,(0,'Locks','Lock Timeouts (timeout > 0)/sec','_Total',NULL)
		,(1,'Locks','Number of Deadlocks/sec','_Total',NULL)
		,(1,'Locks','Lock Requests/sec','_Total',NULL)
		,(1,'Locks','Lock Waits/sec','_Total',NULL)
		,(1,'Locks','Lock Timeouts/sec','_Total',NULL)
		,(1,'Memory Manager','Memory Grants Outstanding','',NULL)
		,(1,'Memory Manager','Memory Grants Pending','',NULL)
		,(1,'Memory Manager','SQL Cache Memory (KB)','',NULL)
		,(1,'Memory Manager','Stolen Server Memory (KB)','',NULL)
		,(1,'Memory Manager','Target Server Memory (KB)','',NULL)
		,(1,'Memory Manager','Total Server Memory (KB)','',NULL)
		,(1,'Memory Manager','Connection Memory (KB)','',NULL)
		,(1,'Memory Manager','Lock Memory (KB)','',NULL)
		,(1,'Memory Manager','Optimizer Memory (KB)','',NULL)
		,(0,'Plan Cache','Cache Hit Ratio','_Total','Cache Hit Ratio Base ')
		,(0,'Plan Cache','Cache Hit Ratio Base','_Total',NULL)
		,(0,'Plan Cache','Cache Object Counts','_Total',NULL)
		,(0,'Resource Pool Stats','Active memory grant amount (KB)','internal',NULL)
		,(0,'Resource Pool Stats','Active memory grants count','internal',NULL)
		,(0,'Resource Pool Stats','Avg Disk Read IO (ms)','internal','Avg Disk Read IO (ms) Base ')
		,(0,'Resource Pool Stats','Avg Disk Read IO (ms) Base','internal',NULL)
		,(0,'Resource Pool Stats','Avg Disk Write IO (ms)','internal','Avg Disk Write IO (ms) Base ')
		,(0,'Resource Pool Stats','Avg Disk Write IO (ms) Base','internal',NULL)
		,(0,'Resource Pool Stats','Cache memory target (KB)','internal',NULL)
		,(0,'Resource Pool Stats','Compile memory target (KB)','internal',NULL)
		,(0,'Resource Pool Stats','CPU control effect %','internal',NULL)
		,(0,'Resource Pool Stats','CPU delayed %','internal','CPU delayed % base ')
		,(0,'Resource Pool Stats','CPU delayed % base','internal',NULL)
		,(0,'Resource Pool Stats','CPU effective %','internal','CPU effective % base ')
		,(0,'Resource Pool Stats','CPU effective % base','internal',NULL)
		,(0,'Resource Pool Stats','CPU usage %','internal','CPU usage % base ')
		,(0,'Resource Pool Stats','CPU usage % base','internal',NULL)
		,(0,'Resource Pool Stats','CPU usage target %','internal',NULL)
		,(0,'Resource Pool Stats','CPU violated %','internal',NULL)
		,(0,'Resource Pool Stats','Disk Read Bytes/sec','internal',NULL)
		,(0,'Resource Pool Stats','Disk Read IO Throttled/sec','internal',NULL)
		,(0,'Resource Pool Stats','Disk Read IO/sec','internal',NULL)
		,(0,'Resource Pool Stats','Disk Write Bytes/sec','internal',NULL)
		,(0,'Resource Pool Stats','Disk Write IO Throttled/sec','internal',NULL)
		,(0,'Resource Pool Stats','Disk Write IO/sec','internal',NULL)
		,(0,'Resource Pool Stats','Max memory (KB)','internal',NULL)
		,(0,'Resource Pool Stats','Memory grant timeouts/sec','internal',NULL)
		,(0,'Resource Pool Stats','Memory grants/sec','internal',NULL)
		,(0,'Resource Pool Stats','Pending memory grants count','internal',NULL)
		,(0,'Resource Pool Stats','Query exec memory target (KB)','internal',NULL)
		,(0,'Resource Pool Stats','Target memory (KB)','internal',NULL)
		,(0,'Resource Pool Stats','Used memory (KB)','internal',NULL)
		,(1,'SQL Errors','Errors/sec','_Total',NULL)
		,(0,'SQL Errors','Errors/sec','DB Offline Errors',NULL)
		,(0,'SQL Errors','Errors/sec','Kill Connection Errors',NULL)
		,(0,'SQL Errors','Errors/sec','User Errors',NULL)
		,(1,'SQL Statistics','Batch Requests/sec','',NULL)
		,(1,'SQL Statistics','Failed Auto-Params/sec','',NULL)
		,(0,'SQL Statistics','SQL Attention rate','',NULL)
		,(1,'SQL Statistics','SQL Compilations/sec','',NULL)
		,(1,'SQL Statistics','SQL Re-Compilations/sec','',NULL)
		,(1,'SQL Statistics','Forced Parameterizations/sec','',NULL)
		,(1,'SQL Statistics','Auto-Param Attempts/sec','',NULL)
		,(0,'Transactions','Longest Transaction Running Time','',NULL)
		,(0,'Transactions','Version Cleanup rate (KB/s)','',NULL)
		,(0,'Transactions','Version Generation rate (KB/s)','',NULL)
		,(1,'Transactions','Free Space in tempdb (KB)','',NULL)
		,(1,'Wait Statistics','Log write waits','Average wait time (ms)',NULL)
		,(1,'Wait Statistics','Network IO waits','Average wait time (ms)',NULL)
		,(1,'Wait Statistics','Page IO latch waits','Average wait time (ms)',NULL)
		,(1,'Wait Statistics','Page latch waits','Average wait time (ms)',NULL)
		,(0,'Wait Statistics','Lock waits','Cumulative wait time (ms) per second',NULL)
		,(0,'Wait Statistics','Memory grant queue waits','Cumulative wait time (ms) per second',NULL)
		,(0,'Wait Statistics','Network IO waits','Cumulative wait time (ms) per second',NULL)
		,(0,'Wait Statistics','Non-Page latch waits','Cumulative wait time (ms) per second',NULL)
		,(1,'Wait Statistics','Page IO latch waits','Cumulative wait time (ms) per second',NULL)
		,(1,'Wait Statistics','Page latch waits','Cumulative wait time (ms) per second',NULL)
		,(0,'Wait Statistics','Wait for the worker','Cumulative wait time (ms) per second',NULL)
		,(0,'Workload Group Stats','Active parallel threads','internal',NULL)
		,(0,'Workload Group Stats','Active requests','internal',NULL)
		,(0,'Workload Group Stats','Avg Disk msec/Read','internal','Disk msec/Read Base ')
		,(0,'Workload Group Stats','Avg Disk msec/Write','internal','Disk msec/Write Base ')
		,(0,'Workload Group Stats','Blocked tasks','internal',NULL)
		,(0,'Workload Group Stats','CPU delayed %','internal','CPU delayed % base ')
		,(0,'Workload Group Stats','CPU delayed % base','internal',NULL)
		,(0,'Workload Group Stats','CPU effective %','internal','CPU effective % base ')
		,(0,'Workload Group Stats','CPU effective % base','internal',NULL)
		,(0,'Workload Group Stats','CPU usage %','internal','CPU usage % base ')
		,(0,'Workload Group Stats','CPU usage % base','internal',NULL)
		,(0,'Workload Group Stats','CPU violated %','internal',NULL)
		,(0,'Workload Group Stats','Disk Read Bytes/sec','internal',NULL)
		,(0,'Workload Group Stats','Disk Reads/sec','internal',NULL)
		,(0,'Workload Group Stats','Disk Violations/sec','internal',NULL)
		,(0,'Workload Group Stats','Disk Write Bytes/sec','internal',NULL)
		,(0,'Workload Group Stats','Disk Writes/sec','internal',NULL)
		,(0,'Workload Group Stats','Max request cpu time (ms)','internal',NULL)
		,(0,'Workload Group Stats','Max request memory grant (KB)','internal',NULL)
		,(0,'Workload Group Stats','Query optimizations/sec','internal',NULL)
		,(0,'Workload Group Stats','Queued requests','internal',NULL)
		,(0,'Workload Group Stats','Reduced memory grants/sec','internal',NULL)
		,(0,'Workload Group Stats','Requests completed/sec','internal',NULL)
		,(0,'Workload Group Stats','Suboptimal plans/sec','internal',NULL)
		,(0,'Workload Group Stats','Disk msec/Read Base','internal',NULL)
		,(0,'Workload Group Stats','Disk msec/Write Base','internal',NULL)
		,(1,'Win32_PerfFormattedData_PerfOS_Processor','Processor Time %','SQL',NULL)
		,(1,'Win32_PerfFormattedData_PerfOS_Processor','Idle Time %','SQL',NULL)
		,(1,'Win32_PerfFormattedData_PerfOS_Processor','Processor Time %','System',NULL)

insert into [dbo].[sqlwatch_config_performance_counters]
select s.* from #sql_perf_mon_config_perf_counters s
left join [dbo].[sqlwatch_config_performance_counters] t
on s.[object_name] = t.[object_name] collate database_default
and s.[instance_name] = t.[instance_name] collate database_default
and s.[counter_name] = t.[counter_name] collate database_default
where t.[counter_name] is null


--------------------------------------------------------------------------------------
-- add snapshot types
--------------------------------------------------------------------------------------
;merge [dbo].[sqlwatch_config_snapshot_type] as target
using (
	/* performance data logger */
	select [snapshot_type_id] = 1, [snapshot_type_desc] = 'Performance', [snapshot_retention_days] = 7
	union 
	/* size data logger */
	select [snapshot_type_id] = 2, [snapshot_type_desc] = 'Disk Utilisation', [snapshot_retention_days] = 365
	union 
	/* indexes */
	select [snapshot_type_id] = 3, [snapshot_type_desc] = 'Missing indexes', [snapshot_retention_days] = 30
	union 
	/* XES Waits */
	select [snapshot_type_id] = 6, [snapshot_type_desc] = 'XES Waits', [snapshot_retention_days] = 7
	union
	/* XES SQLWATCH Long queries */
	select [snapshot_type_id] = 7, [snapshot_type_desc] = 'XES Long Queries', [snapshot_retention_days] = 7
	union
	/* XES SQLWATCH Waits */
	select [snapshot_type_id] = 8, [snapshot_type_desc] = 'XES Waits', [snapshot_retention_days] = 30  --is this used
	union
	/* XES SQLWATCH Blockers */
	select [snapshot_type_id] = 9, [snapshot_type_desc] = 'XES Blockers', [snapshot_retention_days] = 30
	union
	/* XES diagnostics */
	select [snapshot_type_id] = 10, [snapshot_type_desc] = 'XES Query Processing', [snapshot_retention_days] = 30
	union
	/* whoisactive */
	select [snapshot_type_id] = 11, [snapshot_type_desc] = 'WhoIsActive', [snapshot_retention_days] = 3
	union
	/* index usage */
	select [snapshot_type_id] = 14, [snapshot_type_desc] = 'Index Stats', [snapshot_retention_days] = 90
	union
	/* index histogram */
	select [snapshot_type_id] = 15, [snapshot_type_desc] = 'Index Histogram', [snapshot_retention_days] = 90

) as source
on (source.[snapshot_type_id] = target.[snapshot_type_id])
when matched and source.[snapshot_type_desc] <> target.[snapshot_type_desc] then
	update set [snapshot_type_desc] = source.[snapshot_type_desc]
when not matched then
	insert ([snapshot_type_id],[snapshot_type_desc],[snapshot_retention_days])
	values (source.[snapshot_type_id],source.[snapshot_type_desc],source.[snapshot_retention_days])
;

--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------

/* migrate snapshots 1.3.3 to 1.5 */
--query processing has been split out into its own snapshot 10 from snapshot 1.
--we have to backfill header first as there wont be any old records with id 10, it would violate fk reference
--if we dont migrate, the old query processing records will not be available in dashboard.
if (select count(*) from [dbo].[sqlwatch_logger_snapshot_header]
	where [snapshot_type_id] = 10) = 0
		begin
			insert into [dbo].[sqlwatch_logger_snapshot_header]
			select distinct s.[snapshot_time], [snapshot_type_id] = 10, @@SERVERNAME
			from [dbo].[sqlwatch_logger_xes_query_processing] s
				left join [dbo].[sqlwatch_logger_snapshot_header] t
				on t.snapshot_time = s.snapshot_time
				and t.snapshot_type_id = 1
				and s.snapshot_type_id = 10
				and s.sql_instance = t.sql_instance
			where t.snapshot_time is null

			update [dbo].[sqlwatch_logger_xes_query_processing]
				set  [snapshot_type_id] = 10
				where [snapshot_type_id] = 1
				and sql_instance = @@SERVERNAME
		end


--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------


--setup jobs
--we have to switch database to msdb but we also need to know which db jobs should run in so have to capture current database:
declare @server nvarchar(255)
set @server = @@SERVERNAME

USE [msdb]

------------------------------------------------------------------------------------------------------------------
-- job creator engine, March 2019
------------------------------------------------------------------------------------------------------------------
/* rename old jobs to new standard, DB 1.5, March 2019 */
set nocount on;

declare @sql varchar(max) = ''

create table #jobrename (
	old_job sysname, new_job sysname
	)
insert into #jobrename
	values  ('DBA-PERF-AUTO-CONFIG',			'SQLWATCH-INTERNAL-CONFIG'),
			('DBA-PERF-LOGGER',					'SQLWATCH-LOGGER-PERFORMANCE'),
			('DBA-PERF-LOGGER-RETENTION',		'SQLWATCH-INTERNAL-RETENTION'),
			('SQLWATCH-LOGGER-MISSING-INDEXES',	'SQLWATCH-LOGGER-INDEXES')

select @sql = @sql + convert(varchar(max),' if (select name from msdb.dbo.sysjobs where name = ''' + old_job + ''') is not null
	and (select name from msdb.dbo.sysjobs where name = ''' + new_job + ''') is null
	begin
		exec msdb.dbo.sp_update_job @job_name=N''' + old_job + ''', @new_name=N''' + new_job + '''
	end;')
from #jobrename

exec ( @sql )

/* create jobs */
declare @job_description nvarchar(255) = 'https://sqlwatch.io'
declare @job_category nvarchar(255) = 'Data Collector'
declare @database_name sysname = '$(DatabaseName)'
declare @command nvarchar(4000)

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


/* job definition */
insert into #jobs
	values	('SQLWATCH-LOGGER-WHOISACTIVE',		4, 1, 2, 15, 0, 0, 20180101, 99991231, 0,	235959, 0),
			('SQLWATCH-LOGGER-PERFORMANCE',		4, 1, 4, 1,  0, 1, 20180101, 99991231, 12,	235959, 1),
			('SQLWATCH-INTERNAL-RETENTION',		4, 1, 8, 1,  0, 1, 20180101, 99991231, 20,	235959, 1),
			('SQLWATCH-LOGGER-DISK-UTILISATION',4, 1, 8, 1,  0, 1, 20180101, 99991231, 437,	235959, 1),
			('SQLWATCH-LOGGER-INDEXES',			4, 1, 8, 6,  0, 1, 20180101, 99991231, 420,	235959, 1),
			('SQLWATCH-INTERNAL-CONFIG',		4, 1, 8, 1,  0, 1, 20180101, 99991231, 26,  235959, 1)			

/* step definition */
insert into #steps
	values	('dbo.usp_sqlwatch_logger_whoisactive',		1, 'SQLWATCH-LOGGER-WHOISACTIVE',		'TSQL', 'exec dbo.usp_sqlwatch_logger_whoisactive'),

			('dbo.usp_sqlwatch_logger_performance',		1, 'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL', 'exec dbo.usp_sqlwatch_logger_performance'),
			('dbo.usp_sqlwatch_logger_xes_waits',		2, 'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL', 'exec dbo.usp_sqlwatch_logger_xes_waits'),
			('dbo.usp_sqlwatch_logger_xes_blockers',	3, 'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL', 'exec dbo.usp_sqlwatch_logger_xes_blockers'),
			('dbo.usp_sqlwatch_logger_xes_diagnostics',	4, 'SQLWATCH-LOGGER-PERFORMANCE',		'TSQL', 'exec dbo.usp_sqlwatch_logger_xes_diagnostics'),

			('dbo.usp_sqlwatch_internal_retention',		1, 'SQLWATCH-INTERNAL-RETENTION',		'TSQL', 'exec dbo.usp_sqlwatch_internal_retention'),

			('dbo.usp_sqlwatch_logger_disk_utilisation',1, 'SQLWATCH-LOGGER-DISK-UTILISATION',	'TSQL', 'exec dbo.usp_sqlwatch_logger_disk_utilisation'),
			('Get-WMIObject Win32_Volume',		2, 'SQLWATCH-LOGGER-DISK-UTILISATION',	'PowerShell', N'[datetime]$snapshot_time = (Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query "select [snapshot_time]=max([snapshot_time]) 
from [dbo].[sqlwatch_logger_snapshot_header]
where snapshot_type_id = 2").snapshot_time

#https://msdn.microsoft.com/en-us/library/aa394515(v=vs.85).aspx
#driveType 3 = Local disk
Get-WMIObject Win32_Volume | ?{$_.DriveType -eq 3} | %{
    $VolumeName = $_.Name
    $VolumeLabel = $_.Label
    $FileSystem = $_.Filesystem
    $BlockSize = $_.BlockSize
    $FreeSpace = $_.Freespace
    $Capacity = $_.Capacity
    $SnapshotTime = Get-Date $snapshot_time -format "yyyy-MM-dd HH:mm:ss.fff"
    Invoke-SqlCmd -ServerInstance "' + @server + '" -Database ' + '$(DatabaseName)' + ' -Query "
     insert into [dbo].[sqlwatch_logger_disk_utilisation_volume](
            [volume_name]
           ,[volume_label]
           ,[volume_fs]
           ,[volume_block_size_bytes]
           ,[volume_free_space_bytes]
           ,[volume_total_space_bytes]
           ,[snapshot_type_id]
           ,[snapshot_time])
    values (''$VolumeName'',''$VolumeLabel'',''$FileSystem'',$BlockSize,$FreeSpace,$Capacity,2,''$SnapshotTime'')
    " 
}'),
			('dbo.usp_sqlwatch_logger_missing_indexes',		1, 'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_logger_missing_indexes'),
			('dbo.usp_sqlwatch_logger_index_usage_stats',	2, 'SQLWATCH-LOGGER-INDEXES',		'TSQL', 'exec dbo.usp_sqlwatch_logger_index_usage_stats'),
			('dbo.usp_sqlwatch_internal_add_database',	1, 'SQLWATCH-INTERNAL-CONFIG',		'TSQL', 'exec dbo.usp_sqlwatch_internal_add_database')


/* create job and steps */
select @sql = replace(replace(convert(nvarchar(max),(select ' if (select name from sysjobs where name = ''' + job_name + ''') is null 
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
