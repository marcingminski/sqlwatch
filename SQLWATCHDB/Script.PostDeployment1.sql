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

/* 2019-05-05 backfill db create date */
--if (select count(*) from dbo.[sqlwatch_logger_perf_file_stats] where database_create_date = '1900-01-01') > 0
--	begin
--		ALTER TABLE [dbo].[sqlwatch_logger_perf_file_stats] DROP CONSTRAINT [fk_pk_sql_perf_mon_file_stats_database];

--		update fs
--			set [database_create_date] = db.database_create_date
--		from dbo.[sqlwatch_logger_perf_file_stats] fs
--		inner join dbo.sqlwatch_meta_database db
--			on db.[database_name] = fs.[sqlwatch_database_id]
--		where fs.database_create_date = '1900-01-01';

--		ALTER TABLE [dbo].[sqlwatch_logger_perf_file_stats]  WITH NOCHECK ADD  CONSTRAINT [fk_pk_sql_perf_mon_file_stats_database] FOREIGN KEY([sqlwatch_database_id], [database_create_date], [sql_instance])
--		REFERENCES [dbo].[sqlwatch_meta_database] ([database_name], [database_create_date], [sql_instance]) ON UPDATE CASCADE ON DELETE CASCADE;

--		ALTER TABLE [dbo].[sqlwatch_logger_perf_file_stats] CHECK CONSTRAINT [fk_pk_sql_perf_mon_file_stats_database];
--	end


--------------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------------
if (select count(*) from [dbo].[sqlwatch_meta_server]) = 0
	begin
		insert into dbo.[sqlwatch_meta_server] ([physical_name],[servername], [service_name], [local_net_address], [local_tcp_port], [utc_offset_minutes], [sql_version])
		select convert(sysname,SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
			, convert(sysname,@@SERVERNAME), convert(sysname,@@SERVICENAME), convert(varchar(50),local_net_address), convert(varchar(50),local_tcp_port)
			, DATEDIFF(mi, GETUTCDATE(), GETDATE())
			, @@VERSION
		from sys.dm_exec_connections where session_id = @@spid
	end


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
create table #sql_perf_mon_config_perf_counters (
	[object_name] nvarchar(128) not null,
	[instance_name] nvarchar(128) not null,
	[counter_name] nvarchar(128) not null,
	[base_counter_name] nvarchar(128) null,
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
		,(0,'SQL Errors','Errors/sec','_Total',NULL)
		,(1,'SQL Errors','Errors/sec','DB Offline Errors',NULL)
		,(1,'SQL Errors','Errors/sec','Kill Connection Errors',NULL)
		,(1,'SQL Errors','Errors/sec','User Errors',NULL)
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
	select [snapshot_type_id] = 2, [snapshot_type_desc] = 'Disk Utilisation Database', [snapshot_retention_days] = 365
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
	union
	/* agent history */
	select [snapshot_type_id] = 16, [snapshot_type_desc] = 'Agent History', [snapshot_retention_days] = 365
	union
	/* Os volume utilisation */
	select [snapshot_type_id] = 17, [snapshot_type_desc] = 'Disk Utilisation OS', [snapshot_retention_days] = 365
	union
	/* Checks History */
	select [snapshot_type_id] = 18, [snapshot_type_desc] = 'Checks', [snapshot_retention_days] = 2
	union
	/* Actions History */
	select [snapshot_type_id] = 19, [snapshot_type_desc] = 'Actions', [snapshot_retention_days] = 2
	union
	/* Reports History */
	select [snapshot_type_id] = 20, [snapshot_type_desc] = 'Reports', [snapshot_retention_days] = 2

) as source
on (source.[snapshot_type_id] = target.[snapshot_type_id])
when matched and source.[snapshot_type_desc] <> target.[snapshot_type_desc] then
	update set [snapshot_type_desc] = source.[snapshot_type_desc]
when not matched then
	insert ([snapshot_type_id],[snapshot_type_desc],[snapshot_retention_days])
	values (source.[snapshot_type_id],source.[snapshot_type_desc],source.[snapshot_retention_days])
;


--------------------------------------------------------------------------------------
-- wait stat categories
--------------------------------------------------------------------------------------
--declare @wait_categories table (
--	[wait_type] nvarchar(60) not null,
--	[wait_category] nvarchar(60) not null,
--	[report_include] bit not null
--)

--insert into @wait_categories
--VALUES
-- ('HADR_CLUSAPI_CALL','Availability Groups',0)
--,('HADR_FILESTREAM_IOMGR_IOCOMPLETION','Availability Groups',0)
--,('HADR_LOGCAPTURE_WAIT','Availability Groups',0)
--,('HADR_NOTIFICATION_DEQUEUE','Availability Groups',0)
--,('HADR_TIMER_TASK','Availability Groups',0)
--,('HADR_WORK_QUEUE','Availability Groups',0)
--,('FCB_REPLICA_READ','Buffer I/O',1)
--,('FCB_REPLICA_WRITE','Buffer I/O',1)
--,('IO_COMPLETION','Buffer I/O',1)
--,('PAGEIOLATCH_DT','Buffer I/O',1)
--,('PAGEIOLATCH_EX','Buffer I/O',1)
--,('PAGEIOLATCH_KP','Buffer I/O',1)
--,('PAGEIOLATCH_NL','Buffer I/O',1)
--,('PAGEIOLATCH_SH','Buffer I/O',1)
--,('PAGEIOLATCH_UP','Buffer I/O',1)
--,('REPLICA_WRITES','Buffer I/O',1)
--,('PAGELATCH_DT','Buffer Latch',1)
--,('PAGELATCH_EX','Buffer Latch',1)
--,('PAGELATCH_KP','Buffer Latch',1)
--,('PAGELATCH_NL','Buffer Latch',1)
--,('PAGELATCH_SH','Buffer Latch',1)
--,('PAGELATCH_UP','Buffer Latch',1)
--,('RESOURCE_SEMAPHORE_MUTEX','Compilation',1)
--,('RESOURCE_SEMAPHORE_QUERY_COMPILE','Compilation',1)
--,('RESOURCE_SEMAPHORE_SMALL_QUERY','Compilation',1)
--,('MSSEARCH','Full Text Search',1)
--,('SOAP_READ','Full Text Search',1)
--,('SOAP_WRITE','Full Text Search',1)
--,('CHECKPOINT_QUEUE','Idle',0)
--,('CHKPT','Idle',0)
--,('KSOURCE_WAKEUP','Idle',0)
--,('LAZYWRITER_SLEEP','Idle',0)
--,('LOGMGR_QUEUE','Idle',0)
--,('ONDEMAND_TASK_QUEUE','Idle',0)
--,('REQUEST_FOR_DEADLOCK_SEARCH','Idle',0)
--,('RESOURCE_QUEUE','Idle',0)
--,('SERVER_IDLE_CHECK','Idle',0)
--,('SLEEP_BPOOL_FLUSH','Idle',0)
--,('SLEEP_DBSTARTUP','Idle',0)
--,('SLEEP_DCOMSTARTUP','Idle',0)
--,('SLEEP_MSDBSTARTUP','Idle',0)
--,('SLEEP_SYSTEMTASK','Idle',0)
--,('SLEEP_TASK','Idle',0)
--,('SLEEP_TEMPDBSTARTUP','Idle',0)
--,('SNI_HTTP_ACCEPT','Idle',0)
--,('SQLTRACE_BUFFER_FLUSH','Idle',0)
--,('TRACEWRITE','Idle',1)
--,('WAIT_FOR_RESULTS','Idle',0)
--,('WAITFOR_TASKSHUTDOWN','Idle',0)
--,('XE_DISPATCHER_WAIT','Idle',0)
--,('XE_TIMER_EVENT','Idle',0)
--,('DEADLOCK_ENUM_MUTEX','Latch',1)
--,('INDEX_USAGE_STATS_MUTEX','Latch',1)
--,('LATCH_DT','Latch',1)
--,('LATCH_EX','Latch',1)
--,('LATCH_KP','Latch',1)
--,('LATCH_NL','Latch',1)
--,('LATCH_SH','Latch',1)
--,('LATCH_UP','Latch',1)
--,('VIEW_DEFINITION_MUTEX','Latch',1)
--,('LCK_M_BU','Lock',1)
--,('LCK_M_IS','Lock',1)
--,('LCK_M_IU','Lock',1)
--,('LCK_M_IX','Lock',1)
--,('LCK_M_RIn_NL','Lock',1)
--,('LCK_M_RIn_S','Lock',1)
--,('LCK_M_RIn_U','Lock',1)
--,('LCK_M_RIn_X','Lock',1)
--,('LCK_M_RS_S','Lock',1)
--,('LCK_M_RS_U','Lock',1)
--,('LCK_M_RX_S','Lock',1)
--,('LCK_M_RX_U','Lock',1)
--,('LCK_M_RX_X','Lock',1)
--,('LCK_M_S','Lock',1)
--,('LCK_M_SCH_M','Lock',1)
--,('LCK_M_SCH_S','Lock',1)
--,('LCK_M_SIU','Lock',1)
--,('LCK_M_SIX','Lock',1)
--,('LCK_M_U','Lock',1)
--,('LCK_M_UIX','Lock',1)
--,('LCK_M_X','Lock',1)
--,('LOGBUFFER','Logging',1)
--,('LOGMGR','Logging',1)
--,('LOGMGR_FLUSH','Logging',1)
--,('LOGMGR_RESERVE_APPEND','Logging',1)
--,('WRITELOG','Logging',1)
--,('CMEMTHREAD','Memory',1)
--,('LOWFAIL_MEMMGR_QUEUE','Memory',1)
--,('RESOURCE_SEMAPHORE','Memory',1)
--,('SOS_RESERVEDMEMBLOCKLIST','Memory',1)
--,('SOS_VIRTUALMEMORY_LOW','Memory',1)
--,('UTIL_PAGE_ALLOC','Memory',1)
--,('DBMIRROR_DBM_EVENT','Mirroring',0)
--,('DBMIRROR_DBM_MUTEX','Mirroring',1)
--,('DBMIRROR_EVENTS_QUEUE','Mirroring',0)
--,('DBMIRROR_WORKER_QUEUE','Mirroring',0)
--,('DBMIRROR%','Mirroring',1)
--,('DBMIRRORING_CMD','Mirroring',0)
--,('ASYNC_NETWORK_IO','Network I/O',1)
--,('DBMIRROR_SEND','Network I/O',1)
--,('MSQL_DQ','Network I/O',1)
--,('NET_WAITFOR_PACKET','Network I/O',1)
--,('OLEDB','Network I/O',1)
--,('ABR','Other',1)
--,('BAD_PAGE_PROCESS','Other',1)
--,('BROKER_CONNECTION_RECEIVE_TASK','Other',1)
--,('BROKER_ENDPOINT_STATE_MUTEX','Other',1)
--,('BROKER_REGISTERALLENDPOINTS','Other',1)
--,('BROKER_SHUTDOWN','Other',1)
--,('BROKER_TASK_STOP','Other',0)
--,('CHECK_PRINT_RECORD','Other',1)
--,('CURSOR_ASYNC','Other',1)
--,('DAC_INIT','Other',1)
--,('DBCC_COLUMN_TRANSLATION_CACHE','Other',1)
--,('DBTABLE','Other',1)
--,('DUMPTRIGGER','Other',1)
--,('EC','Other',1)
--,('EE_SPECPROC_MAP_INIT','Other',1)
--,('EXECUTION_PIPE_EVENT_INTERNAL','Other',1)
--,('FAILPOINT','Other',1)
--,('FT_RESTART_CRAWL','Other',1)
--,('FT_RESUME_CRAWL','Other',1)
--,('FULLTEXT GATHERER','Other',1)
--,('GUARDIAN','Other',1)
--,('HTTP_ENDPOINT_COLLCREATE','Other',1)
--,('HTTP_ENUMERATION','Other',1)
--,('HTTP_START','Other',1)
--,('IMP_IMPORT_MUTEX','Other',1)
--,('IMPPROV_IOWAIT','Other',1)
--,('INTERNAL_TESTING','Other',1)
--,('IO_AUDIT_MUTEX','Other',1)
--,('KTM_ENLISTMENT','Other',1)
--,('KTM_RECOVERY_MANAGER','Other',1)
--,('KTM_RECOVERY_RESOLUTION','Other',1)
--,('MIRROR_SEND_MESSAGE','Other',1)
--,('MISCELLANEOUS','Other',1)
--,('MSQL_SYNC_PIPE','Other',1)
--,('MSQL_XP','Other',1)
--,('PARALLEL_BACKUP_QUEUE','Other',1)
--,('PRINT_ROLLBACK_PROGRESS','Other',1)
--,('QNMANAGER_ACQUIRE','Other',1)
--,('QPJOB_KILL','Other',1)
--,('QPJOB_WAITFOR_ABORT','Other',1)
--,('QRY_MEM_GRANT_INFO_MUTEX','Other',1)
--,('QUERY_ERRHDL_SERVICE_DONE','Other',1)
--,('QUERY_EXECUTION_INDEX_SORT_EVENT_OPEN','Other',1)
--,('QUERY_NOTIFICATION_MGR_MUTEX','Other',1)
--,('QUERY_NOTIFICATION_SUBSCRIPTION_MUTEX','Other',1)
--,('QUERY_NOTIFICATION_TABLE_MGR_MUTEX','Other',1)
--,('QUERY_NOTIFICATION_UNITTEST_MUTEX','Other',1)
--,('QUERY_OPTIMIZER_PRINT_MUTEX','Other',1)
--,('QUERY_REMOTE_BRICKS_DONE','Other',1)
--,('QUERY_TRACEOUT','Other',1)
--,('RECOVER_CHANGEDB','Other',1)
--,('REPL_CACHE_ACCESS','Other',1)
--,('REPL_SCHEMA_ACCESS','Other',1)
--,('REQUEST_DISPENSER_PAUSE','Other',1)
--,('SEC_DROP_TEMP_KEY','Other',1)
--,('SEQUENTIAL_GUID','Other',1)
--,('SHUTDOWN','Other',1)
--,('SNI_CRITICAL_SECTION','Other',1)
--,('SNI_HTTP_WAITFOR_0_DISCON','Other',1)
--,('SNI_LISTENER_ACCESS','Other',1)
--,('SNI_TASK_COMPLETION','Other',1)
--,('SOS_CALLBACK_REMOVAL','Other',1)
--,('SOS_DISPATCHER_MUTEX','Other',1)
--,('SOS_LOCALALLOCATORLIST','Other',1)
--,('SOS_OBJECT_STORE_DESTROY_MUTEX','Other',1)
--,('SOS_PROCESS_AFFINITY_MUTEX','Other',1)
--,('SOS_STACKSTORE_INIT_MUTEX','Other',1)
--,('SOS_SYNC_TASK_ENQUEUE_EVENT','Other',1)
--,('SOSHOST_EVENT','Other',1)
--,('SOSHOST_INTERNAL','Other',1)
--,('SOSHOST_MUTEX','Other',1)
--,('SOSHOST_RWLOCK','Other',1)
--,('SOSHOST_SEMAPHORE','Other',1)
--,('SOSHOST_SLEEP','Other',1)
--,('SOSHOST_TRACELOCK','Other',1)
--,('SOSHOST_WAITFORDONE','Other',1)
--,('SQLSORT_NORMMUTEX','Other',1)
--,('SQLSORT_SORTMUTEX','Other',1)
--,('SQLTRACE_LOCK','Other',1)
--,('SQLTRACE_SHUTDOWN','Other',1)
--,('SQLTRACE_WAIT_ENTRIES','Other',0)
--,('SRVPROC_SHUTDOWN','Other',1)
--,('TEMPOBJ','Other',1)
--,('THREADPOOL','CPU',1)
--,('TIMEPRIV_TIMEPERIOD','Other',1)
--,('VIA_ACCEPT','Other',1)
--,('WAITSTAT_MUTEX','Other',1)
--,('WCC','Other',1)
--,('WORKTBL_DROP','Other',1)
--,('XE_BUFFERMGR_ALLPROCECESSED_EVENT','Other',1)
--,('XE_BUFFERMGR_FREEBUF_EVENT','Other',1)
--,('XE_DISPATCHER_JOIN','Other',0)
--,('XE_MODULEMGR_SYNC','Other',1)
--,('XE_OLS_LOCK','Other',1)
--,('XE_SERVICES_MUTEX','Other',1)
--,('XE_SESSION_CREATE_SYNC','Other',1)
--,('XE_SESSION_SYNC','Other',1)
--,('XE_STM_CREATE','Other',1)
--,('XE_TIMER_MUTEX','Other',1)
--,('XE_TIMER_TASK_DONE','Other',1)
--,('CXPACKET','Parallelism',1)
--,('REPL%','Replication',1)
--,('CLR_AUTO_EVENT','SQLCLR',0)
--,('CLR_RWLOCK_WRITER','SQLCLR',1)
--,('SQLCLR_APPDOMAIN','SQLCLR',1)
--,('SQLCLR_ASSEMBLY','SQLCLR',1)
--,('SQLCLR_DEADLOCK_DETECTION','SQLCLR',1)
--,('SQLCLR_QUANTUM_PUNISHMENT','SQLCLR',1)
--,('DTC','Transaction',1)
--,('DTC_ABORT_REQUEST','Transaction',1)
--,('DTC_RESOLVE','Transaction',1)
--,('MSQL_XACT_MGR_MUTEX','Transaction',1)
--,('MSQL_XACT_MUTEX','Transaction',1)
--,('TRAN_MARKLATCH_DT','Transaction',1)
--,('TRAN_MARKLATCH_EX','Transaction',1)
--,('TRAN_MARKLATCH_KP','Transaction',1)
--,('TRAN_MARKLATCH_NL','Transaction',1)
--,('TRAN_MARKLATCH_SH','Transaction',1)
--,('TRAN_MARKLATCH_UP','Transaction',1)
--,('TRANSACTION_MUTEX','Transaction',1)
--,('XACT_OWN_TRANSACTION','Transaction',1)
--,('XACT_RECLAIM_SESSION','Transaction',1)
--,('XACTLOCKINFO','Transaction',1)
--,('XACTWORKSPACE_MUTEX','Transaction',1)
--,('WAITFOR','User Waits',0)
--,('BROKER_TO_FLUSH','Other',0)
--,('CXCONSUMER','Other',0)
--,('DIRTY_PAGE_POLL','Other',0)
--,('DISPATCHER_QUEUE_SEMAPHORE','Other',0)
--,('FT_IFTS_SCHEDULER_IDLE_WAIT','Other',0)
--,('FT_IFTSHC_MUTEX','Other',0)
--,('MEMORY_ALLOCATION_EXT','Other',0)
--,('PARALLEL_REDO_DRAIN_WORKER','Availability Groups',0)
--,('PARALLEL_REDO_LOG_CACHE','Availability Groups',0)
--,('PARALLEL_REDO_TRAN_LIST','Availability Groups',0)
--,('PARALLEL_REDO_WORKER_SYNC','Availability Groups',0)
--,('PARALLEL_REDO_WORKER_WAIT_WORK','Availability Groups',0)
--,('PREEMPTIVE_XE_GETTARGETSTATE','Other',0)
--,('PWAIT_ALL_COMPONENTS_INITIALIZED','Other',0)
--,('PWAIT_DIRECTLOGCONSUMER_GETNEXT','Other',0)
--,('QDS_ASYNC_QUEUE','Other',0)
--,('QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP','Other',0)
--,('QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','Other',0)
--,('QDS_SHUTDOWN_QUEUE','Other',0)
--,('REDO_THREAD_PENDING_WORK','Availability Groups',0)
--,('SLEEP_MASTERDBREADY','Other',0)
--,('SLEEP_MASTERMDREADY','Other',0)
--,('SLEEP_MASTERUPGRADED','Other',0)
--,('SOS_WORK_DISPATCHER','Other',0)
--,('SP_SERVER_DIAGNOSTICS_SLEEP','Other',0)
--,('SQLTRACE_INCREMENTAL_FLUSH_SLEEP','Other',0)
--,('WAIT_XTP_CKPT_CLOSE','Other',0)
--,('WAIT_XTP_HOST_WAIT','Other',0)
--,('WAIT_XTP_OFFLINE_CKPT_NEW_LOG','Other',0)
--,('WAIT_XTP_RECOVERY','Other',0)
--,('SOS_SCHEDULER_YIELD','CPU',1)

--merge [dbo].[sqlwatch_config_wait_stats] as target
--using @wait_categories as source
--on (target.[wait_type] = source.[wait_type])

--when matched and (target.[wait_category] <> source.[wait_category]
--	or target.[report_include] <> source.[report_include])
--then update	
--	set [wait_category] = source.[wait_category],
--		[report_include] = source.[report_include]

--when not matched by target then
--	insert (wait_type, wait_category, report_include)
--	values (source.wait_type, source.wait_category, source.report_include);

--------------------------------------------------------------------------------------
-- perf counters poster
-- TO DO this sloud integrate into the [sqlwatch_config_performance_counters]
--------------------------------------------------------------------------------------
--declare @poster table (
--	[object_name] nvarchar(128) not null,
--	[counter_name] nvarchar(128) not null,
--	[desired_value_desc] varchar(100),
--	[desired_value] varchar(100),
--	[description] varchar(2048)
--)
--insert into @poster
--values
-- ('SQLServer:Access Methods','Full Scans/sec','1 Full Scan/sec per 1000 Index Searches/sec','0.001','Monitors the number of full scans on tables or indexes. Ignore unless high CPU coincides with high scan rates. High scan rates may be caused by missing indexes, very small tables, or requests for too many records. A sudden increase in this value may indicate a statistics threshold has been reached, resulting in an index no longer being used.')
--,('SQLServer:SQL Statistics','Batch Requests/Sec','','','Number of batch requests received per second, and is a good general indicator for the activity level of the SQL Server. This counter is highly dependent on the hardware and quality of code running on the server. The more powerful the hardware, the higher this number can be, even on poorly coded applications. A value of 1000 batch requests/sec is easily attainable though a typical 100Mbs NIC can only handle about 3000 batch requests/sec.Many other counter thresh- olds depend upon batch requests/sec while, in some cases, a low (or high) number does not point to poor processing power. You should frequently use this counter in combination with other counters, such as processor utilization or user connections.In version 2000, “Transactions/ sec” was the counter most often used to measure overall activity, while versions 2005 and later use “Batch Requests/sec”. Versions 2005 prior to SP2, measure this counter differently and may lead to some misunderstandings. Read the footnote for more details.')
--,('SQLServer:SQL Statistics','SQL Compilations/sec','< 10% of the number of Batch Re- quests/Sec','0.1','Number of times that Transact-SQL compilations occurred, per second (including recompiles). The lower this value is the better. High values often indicate excessive adhoc querying and should be as low as possible. If excessive adhoc querying is happening, try rewriting the queries as procedures or invoke the queries using sp_ex- ecuteSQL. When rewriting isn’t possible, consider using a plan guide or setting the database to parameterization forced mode.')
--,('SQLServer:SQL Statistics','SQL Re-Compila- tions/sec','< 10% of the number of SQL Compila- tions/sec','0.1','Number of times, per second, that Transact-SQL objects attempted to be executed but had to be recompiled before completion. This number should be at or near zero, since recompiles can cause deadlocks and exclusive compile locks. This counter’s value should follow in proportion to “Batch Requests/sec” and “SQL Compilations/ sec”. This needs to be nil in your system as much as possible.')
--,('SQLServer:Access Methods','Page Splits/sec','< 20 per 100 Batch Requests/Sec','0.2','Monitors the number of page splits per second which occur due to overflowing index pages and should be as low as possible. To avoid page splits, review table and index design to reduce non-sequential inserts or implement fillfactor and pad_index to leave more empty space per page. NOTE: A high value for this counter is not bad in situations where many new pages are being created, since it includes new page allocations.')
--,('SQLServer:Access Methods','Index Searches/sec','1 Full Scan/sec per 1000 Index Searches/sec','0.001','Monitors the number of index searches when doing range scans, single index record fetches, and repositioning within an index. The threshold recommendation is strictly for OLTP workloads.')
--,('SQL Server:Buffer Manager','Free list stalls/sec','< 2','2','Monitors the number of requests per second where data requests stall because no buffers are available. Any value above 2 means SQL Server needs more memory.number of requests per second where data requests stall because no buffers are available. Any value above 2 means SQL Server needs more memory.')
--,('SQL Server:Buffer Manager','Lazy writes/sec','< 20','20','Monitors the number of times per second that the Lazy Writer process moves dirty pages from the buffer to disk as it frees up buffer space. Lower is better with zero being ideal. When greater than 20, this counter indicates a need for more memory.')
--,('SQL Server:Buffer Manager','Page reads/sec','< 90','90','Number of physical database page reads issued per second. Normal OLTP workloads support 80 – 90 per second, but higher values may be a yellow flag for poor indexing or insufficient memory.')
--,('SQL Server:Buffer Manager','Page lookups/sec','(Page lookups/ sec) / (Batch Requests/ sec) < 100','100','The number of requests to find a page in the buffer pool. When the ratio of batch requests to page lookups crests 100, you may have inefficient execution plans or too many adhoc queries.')
--,('SQL Server:Buffer Manager','Page writes/sec','< 90','90','Number of database pages physically written to disk per second. Normal OLTP workloads support 80 – 90 per second. Values over 90 should be crossed checked with “lazy writer/sec” and “checkpoint” counters. If the other counters are also high, then it may indicate insufficient memory.')
--,('SQL Server:Locks','Average Wait Time (ms)','<500','500','The average wait time, in milliseconds, for each lock request that had to wait. An average wait time longer than 500ms may indicate excessive blocking. This value should generally correlate to “Lock Waits/sec” and move up or down with it accordingly.')
--,('SQL Server:Locks','Lock Requests/sec','<1000','1000','The number of new locks and locks converted per second. This metric’s value should generally correspond to “Batch Re- quests/sec”. Values > 1000 may indicate queries are accessing very large numbers of rows and may benefit from tuning.')
--,('SQL Server:Locks','Lock Timeouts/sec','<1','1','Shows the number of lock requests per second that timed out, including internal requests for NOWAIT locks. A value greater than zero might indicate that user queries are not completing. The lower this value is, the better.')
--,('SQL Server:Locks','Lock Waits/sec','0','0.1','How many times users waited to acquire a lock over the past second. Values greater than zero indicate at least some blocking is occurring, while a value of zero can quickly eliminate blocking as a potential root-cause problem. As with “Lock Wait Time”, lock waits are not recorded by Perf- Mon until after the lock event completes.')
--,('SQL Server:Latches','Latch Waits/sec','(Total Latch Wait Time) / (Latch Waits/ Sec) < 10','10','The number of latches in the last second that had to wait. Latches are lightweight means of holding a very transient server resource, such as an address in memory.')
--,('SQL Server:Buffer Manager','Readahead pages/sec','< 20% of Page Reads/ sec','0.2','Number of data pages read per second in anticipation of their use. If this value is makes up even a sizeable minority of total Page Reads/sec (say, greater than 20% of total page reads), you may have too many physical reads occurring.')
--,('SQL Server:Locks','Number of Deadlocks/sec','<1','1','Number of lock requests, per second, which resulted in a deadlock. Since only a COMMIT, ROLLBACK, or deadlock can terminate a transaction (excluding failures or errors), this is an important value to track. Excessive deadlocking indicates a table or index design error or bad application design.')
--,('SQLServer:Memory Manager','Memory Grants Outstanding','','','Total number of processes per second that have successfully acquired a workspace memory grant.')
--,('SQLServer:Memory Manager','Memory Grants Pending','<1','1','Total number of processes per second waiting for a workspace memory grant. Numbers higher than 0 indicate a lack of memory.')
--,('SQLServer:Memory Manager','Total Server Memory (KB)','','','Shows the amount of memory that SQL Server is currently using. This value should grow until its equal to Target Server Memory, as it popu- lates its caches and loads pages into memory. When it has finished, SQL Server is said to be in a “steady-state”. Until it is in steady-state, per- formance may be slow and IO may be higher.')
--,('SQLServer:Memory Manager','Target Server Memory (KB)','','','Shows the amount of memory that SQL Server wants to use based on the configured Max Server Memory.')
--,('SQLServer:Memory Manager','Stolen Server Memory (KB)','','','Tells how many pages were “stolen” from the buffer pool to satisfy other memory needs, such as plan cache and workspace memory. This number is a good metric to determine how much data is flowing into SQL Server caches and should remain proportionate to “Batch Requests/sec”. Also remember to look for where these stolen pages might be stolen from – optimizer memory, lock memory, and so forth.')
--,('SQL Server:Buffer Manager','Buffer cache hit ratio','100','100','Long a stalwart counter used by SQL Server DBAs, this counter is no longer very useful. It monitors the percentage of data requests answer from the buffer cache since the last reboot. However, other counters are much better for showing current memory pressure that this one because it blows the curve. For example, PLE (page life expectancy) might suddenly drop from 2000 to 70, while buffer cache hit ration moves only from 98.2 to 98.1. Only be concerned by this counter if it’s value is regularly below 90 (for OLTP) or 80 (for very large OLAP).')
--,('SQLServer:Buffer Node','Page life expectancy','>300','300','Tells, on average, how many seconds SQL Server expects a data page to stay in cache. The target on an OLTP system should be at least 300 (5 min). When under 300, this may indicate poor index design (leading to increased disk I/O and less effective use of memory) or, simply, a potential shortage of memory.')
--,('SQLServer:General Statistics','Logins/sec','<2','2','The number of user logins per second. Any value over 2 may indicate insufficient connection pooling.')
--,('SQLServer:SQL Errors','Errors/sec','0','0','Number of errors per second which takes a database offline or kills a user connection, respectively. Since these are severe errors, they should occur very infrequently.')
--,('SQL Server:Databases','Log Growths','0','0','Total number of times the transaction log for the database has been expanded. Each time the transaction log grows, all user activity must halt until the log growth completes. Therefore, you want log growths to occur during predefined maintenance windows rather than during gen- eral working hours.')
--,('SQLServer:SQL Statistics','Auto-Param Attempts/sec','','','Number of auto-parameterization attempts per second. Total should be the sum of the failed, safe, and unsafe auto-parameterizations. Auto-parameterization occurs when an instance of SQL Server attempts to reuse a cached plan for a previously executed query that is similar to, but not the same as, the current query. For more information, see Auto- parameterization in the SQL Server Books On-Line (BOL).')
--,('SQLServer:SQL Statistics','Failed Auto-Params/sec','','','Number of failed auto-parameterization attempts per second. This should be small.')

--merge [dbo].[sqlwatch_config_performance_counters_poster] as target
--using @poster as source
--on source.[object_name] = target.[object_name]
--and source.[counter_name] = target.[counter_name]
--and @@SERVERNAME = target.[sql_instance]

--when not matched then
--	insert ([object_name], [counter_name], [desired_value_desc], [desired_value], [description], [sql_instance])
--	values (source.[object_name], source.[counter_name], source.[desired_value_desc], source.[desired_value], source.[description], @@SERVERNAME);

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
		end;


--------------------------------------------------------------------------------------
-- load default report styles:
--------------------------------------------------------------------------------------
if not exists (select * from [dbo].[sqlwatch_config_report_style] where [report_style_id] = -1)
	begin
		set identity_insert [dbo].[sqlwatch_config_report_style] on
		insert into [dbo].[sqlwatch_config_report_style] ([report_style_id], [style])
		values (-1,'body {font-family: "Trebuchet MS",Helvetica,sans-serif; font-size: 12px;}
table.sqlwatchtbl { border: 1px solid #AAAAAA; background-color: #FEFEFE; width: 100%; text-align: left; border-collapse: collapse; }
table.sqlwatchtbl td, table.sqlwatchtbl th { border: 1px solid #AAAAAA; padding: 3px 3px; }
table.sqlwatchtbl tbody td { color: #333333; }
table.sqlwatchtbl tr:nth-child(even) { background: #EEEEEE; }
table.sqlwatchtbl thead { background: #7C008C; }
table.sqlwatchtbl thead th { font-size: 12px; font-weight: bold; color: #FFFFFF;}
.code {display:block;background:#ddd; margin-top:0.8em;padding-left:10px;padding-bottom:1em;white-space: pre;}'
)
		set identity_insert [dbo].[sqlwatch_config_report_style] off;
	end

--------------------------------------------------------------------------------------
-- default action template
--------------------------------------------------------------------------------------
declare @action_tempalte_plain nvarchar(max) = 'Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )

Current status:  {CHECK_STATUS}
Current value: {CHECK_VALUE}

Previous value: {CHECK_LAST_VALUE}
Previous status: {CHECK_LAST_STATUS}
Previous change: {LAST_STATUS_CHANGE}

SQL instance: {SQL_INSTANCE}
Alert time: {CHECK_TIME}

Warning threshold: {THRESHOLD_WARNING}
Critical threshold: {THRESHOLD_CRITICAL}

--- Check Description:

{CHECK_DESCRIPTION}

--- Check Query:

{CHECK_QUERY}

---

Sent from SQLWATCH on host: {SQL_INSTANCE}
https://docs.sqlwatch.io'

declare @action_tempalte_report_html nvarchar(max) = '<p>Check: {CHECK_NAME} ( CheckId: {CHECK_ID} )</p>

<p>Current status: <b>{CHECK_STATUS}</b>
<br>Current value: <b>{CHECK_VALUE}</b></p>

<p>Previous value: {CHECK_LAST_VALUE}
<br>Previous status: {CHECK_LAST_STATUS}
<br>Previous change: {LAST_STATUS_CHANGE}</p>

<p>SQL instance: <b>{SQL_INSTANCE}</b>
<br>Alert time: <b>{CHECK_TIME}</b></p>

<p>Warning threshold: {THRESHOLD_WARNING}
<br>Critical threshold: {THRESHOLD_CRITICAL}</p>

<p>--- Check Description:</p>

<p>{CHECK_DESCRIPTION}</p>

<p>--- Check Query:</p>

<p><span style="display:block;background:#ddd; margin-top:0.8em;padding-left:10px;padding-bottom:1em;padding-top:1em;white-space: pre;"><code>{CHECK_QUERY}</code></span></p>

<p>--- Report Content:</p></p>

<p><b>{REPORT_TITLE}</b></p>
<p>{REPORT_DESCRIPTION}</p>
<p>{REPORT_CONTENT}</p>

<p>Sent from SQLWATCH on host: {SQL_INSTANCE}</p>
<p><a href="https://docs.sqlwatch.io">https://docs.sqlwatch.io</a> </p>';

disable trigger [dbo].[trg_sqlwatch_config_check_action_template_modify] on [dbo].[sqlwatch_config_check_action_template];  --so we dont populate updated date as this is to detect if a user has modified default template
set identity_insert [dbo].[sqlwatch_config_check_action_template] on;
merge [dbo].[sqlwatch_config_check_action_template] as target
using (
	select
		 [action_template_id] = -1
		,[action_template_description] = 'Default plain notification template (Text). This template is usually used for simple actions that send plain text messages on the back of the check.'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_tempalte_plain
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_tempalte_plain
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_tempalte_plain

	union all

	select
		 [action_template_id] = -2
		,[action_template_description] = 'Default report notification template (HTML). This template is used for actions that trigger reports on the back of the check.'
		,[action_template_fail_subject] = '{CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_fail_body] = @action_tempalte_report_html
		,[action_template_repeat_subject] = 'REPEATED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_repeat_body] = @action_tempalte_report_html
		,[action_template_recover_subject] = 'RECOVERED: {CHECK_STATUS}: {CHECK_NAME} on {SQL_INSTANCE}'
		,[action_template_recover_body]	= @action_tempalte_report_html
		) as source
on target.[action_template_id] = source.[action_template_id]
when not matched then
	insert ( [action_template_id]
			,[action_template_description]
			,[action_template_fail_subject]
			,[action_template_fail_body]
			,[action_template_repeat_subject]
			,[action_template_repeat_body]
			,[action_template_recover_subject]
			,[action_template_recover_body]
			)
	values (
			 source.[action_template_id]
			,source.[action_template_description]
			,source.[action_template_fail_subject]
			,source.[action_template_fail_body]
			,source.[action_template_repeat_subject]
			,source.[action_template_repeat_body]
			,source.[action_template_recover_subject]
			,source.[action_template_recover_body]
			)
when matched and target.[date_updated] is null then --only update when not modified by a user
	update set [action_template_description] = source.[action_template_description]
			,[action_template_fail_subject] = source.[action_template_fail_subject]
			,[action_template_fail_body] = source.[action_template_fail_body]
			,[action_template_repeat_subject] = source.[action_template_repeat_subject]
			,[action_template_repeat_body] = source.[action_template_repeat_body]
			,[action_template_recover_subject] = source.[action_template_recover_subject]
			,[action_template_recover_body] = source.[action_template_recover_body]
;
set identity_insert [dbo].[sqlwatch_config_check_action_template] off;
enable trigger [dbo].[trg_sqlwatch_config_check_action_template_modify] on [dbo].[sqlwatch_config_check_action_template];

--------------------------------------------------------------------------------------
-- load default actions that DO NOT call reports
--------------------------------------------------------------------------------------
disable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];
set identity_insert [dbo].[sqlwatch_config_action] on;

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -1
	,@action_description = 'Send Email to DBAs using sp_send_mail  (HTML)'
	,@action_exec_type = 'T-SQL'
	,@action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''dba@yourcompany.com'',
@subject = ''{SUBJECT}'',
@body = ''{BODY}'',
@profile_name=''DBA'',
@body_format = ''HTML'''
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -2
	,@action_description = 'Send Email to DBAs using sp_send_mail'
	,@action_exec_type = 'T-SQL'
	,@action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''dba@yourcompany.com'',
@subject = ''{SUBJECT}'',
@body = ''{BODY}'',
@profile_name=''DBA'''
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -3
	,@action_description = 'Push notifiction via Pushover'
	,@action_exec_type = 'PowerShell'
	,@action_exec = '$uri = "https://api.pushover.net/1/messages.json"
$parameters = @{
  token = "YOUR_TOKEN"
  user = "USER_TOKEN"
  message = "{SUBJECT} {BODY}"
}
$parameters | Invoke-RestMethod -Uri $uri -Method Post'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -4
	,@action_description = 'Send Email using Send-MailMessage and external SMTP'
	,@action_exec_type = 'PowerShell'
	,@action_exec = 'Send-MailMessage -From ''DBA <dba@yourcompany.com>'' -To ''dba@yourcompany.com'' -Subject "{SUBJECT}" -Body "{BODY}" -SmtpServer "smtp.yourcompany.com"'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -5
	,@action_description = 'Save File on Shared Drive'
	,@action_exec_type = 'PowerShell'
	,@action_exec = '"{BODY}" | Out-File -FilePath \\yourshare\Folder\export.csv'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -6
	,@action_description = 'Send Alert to ZABBIX'
	,@action_exec_type = 'PowerShell'
	,@action_exec = 'zabbix_sender.exe -z zabbix.yourcompany.com -s "SQL_INSTANCE" -k your.check.name -o "{BODY}"'
	,@action_enabled = 0

set identity_insert [dbo].[sqlwatch_config_action] off;
enable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];
--------------------------------------------------------------------------------------
-- load default reports 
--------------------------------------------------------------------------------------
set identity_insert [dbo].[sqlwatch_config_report] on;
disable trigger dbo.trg_sqlwatch_config_report_updated_U on [dbo].[sqlwatch_config_report];

--Indexes with high fragmentation
exec [dbo].[usp_sqlwatch_user_add_report] 
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
	,@report_definition_type = 'Query'
	,@report_action_id  = -1

--Agent Jobs failed in the last 5 minutes
exec [dbo].[usp_sqlwatch_user_add_report] 
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
	select last_check_date
	from [dbo].[sqlwatch_meta_check]
	where check_id = -1
	and sql_instance = @@SERVERNAME
),getdate())
	and sjh.run_status = 0
)
select (select +
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
exec [dbo].[usp_sqlwatch_user_add_report] 
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
select (select 
	''<hr>
<h3>Blocking SPID: '' + convert(varchar(10),c1.blocking_spid) + ''</h3>
Database Name: <b>['' + c1.[database_name] + '']</b>
<br>Blocking App: <b>'' + + c1.blocking_client_app_name + ''</b>
<br>Blocking Host: <b>'' + c1.blocking_client_hostname + ''</b>
<br>Blocking SQL: <span style="display:block;background:#ddd; margin-top:0.8em;padding-left:10px;padding-bottom:1em;white-space: pre;"><code>'' + c1.blocking_sql + ''</code></span></p>
'' +
	( select char(10) + ''<p style="margin-left:25px;background:red;padding:10px;">
Blocking start time: '' + convert(varchar(23),c2.[blocking_start_time],121) + char(10) + ''
<br>Blocked SPID: <b>'' + convert(varchar(10),c2.blocked_spid) + ''</b>
<br>Blocked for: '' + convert(varchar,dateadd(ms,c2.blocking_duration_ms,0),114) + ''
<br>Blocked SQL: <span style="display:block;background:#ddd; margin-top:0.8em;padding-left:10px;padding-bottom:1em;white-space: pre;" ><code>'' + c2.[blocked_sql] + ''</code></span></p>''
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
exec [dbo].[usp_sqlwatch_user_add_report] 
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
	,@report_definition_type = 'Query'
	,@report_action_id  = -1;

set identity_insert [dbo].[sqlwatch_config_report] off;
enable trigger dbo.trg_sqlwatch_config_report_updated_U on [dbo].[sqlwatch_config_report];

--------------------------------------------------------------------------------------
-- now load actions that call reports we have just created
--------------------------------------------------------------------------------------
disable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];
set identity_insert [dbo].[sqlwatch_config_action] on;

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -7
	,@action_description = 'Run Failed Agent Jobs Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -2
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -8
	,@action_description = 'Run Blocked Process Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -3
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_user_add_action]
	 @action_id = -9
	,@action_description = 'Run Disk Utilisation Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -4
	,@action_enabled = 1

set identity_insert [dbo].[sqlwatch_config_action] off;
enable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];

-------------------------------------------------------------------------------------
-- Load default checks
--------------------------------------------------------------------------------------
disable trigger dbo.trg_sqlwatch_config_check_U on [dbo].[sqlwatch_config_check];
set identity_insert [dbo].[sqlwatch_config_check] on;

exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -1
	,@check_name = 'Agent Job failure' 
	,@check_description = 'One or more SQL Server Agent Jobs have failed.
If there is a report assosiated with this check, details of the failures should be inlcuded below.'
	,@check_query = 'select count(*)
from msdb.dbo.sysjobhistory 
where msdb.dbo.agent_datetime(run_date, run_time) >= isnull((
	select last_check_date
	from [dbo].[sqlwatch_meta_check]
	where check_id = -1
	and sql_instance = @@SERVERNAME
),getdate())
and run_status = 0'
	,@check_frequency_minutes = NULL
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>0'
	,@check_enabled = 1
	,@check_action_id = -7

	,@action_every_failure = 1
	,@action_recovery = 0
	,@action_repeat_period_minutes = 1
	,@action_hourly_limit = 60
	,@action_template_id = -2

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -2
	,@check_name = 'Blocking detected'
	,@check_description = 'One or more blocking chains have been detected.
Blocking means processes are stuck and unable to carry any work, could cause downtime or major outage.
If there is a report assosiated with this check, details of the blocking chain should be included below.'
	,@check_query = 'select count(distinct blocked_spid)
from dbo.sqlwatch_logger_xes_blockers b
where snapshot_time >= isnull((
	select last_check_date
	from [dbo].[sqlwatch_meta_check]
	where check_id = -2
	and sql_instance = @@SERVERNAME
	),getdate())'
	,@check_frequency_minutes = NULL
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>0'
	,@check_enabled = 1
	,@check_action_id = -8

	,@action_every_failure = 1
	,@action_recovery = 0
	,@action_repeat_period_minutes = 1
	,@action_hourly_limit = 60
	,@action_template_id = -2

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -3
	,@check_name = 'High CPU Utilistaion % in the last 5 minutes'
	,@check_description = 'In the past 5 minutes, the average CPU utilistaion was higher than expected'
	,@check_query = 'select avg(cntr_value_calculated) 
from dbo.vw_sqlwatch_report_fact_perf_os_performance_counters
where counter_name = ''Processor Time %''
and sql_instance = @@SERVERNAME
and report_time > dateadd(minute,-5,getutcdate())'
	,@check_frequency_minutes = 5
	,@check_threshold_warning = '>60'
	,@check_threshold_critical = '>80'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = NULL
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -4
	,@check_name = 'SQL Server Uptime is low'
	,@check_description = 'SQL Server Uptime Minutes is lower than expected. The server could have been restared in the last 60 minutes.'
	,@check_query = 'select datediff(minute,sqlserver_start_time,getdate()) from sys.dm_os_sys_info'
	,@check_frequency_minutes = 10
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '<60'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 0
	,@action_repeat_period_minutes = NULL
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -5
	,@check_name = 'Action queue is high'
	,@check_description = 'There is a large number of items awaiting action. This could indicate a problem with the action mechanism.
Note that in this context, the succesful action means that the item was succesfuly executed, for example sp_send_dbmail and not that the email was delivered.'
	,@check_query = 'select count(*) from dbo.sqlwatch_meta_action_queue where exec_status is null or exec_status <> ''OK'''
	,@check_frequency_minutes = 5
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>10'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 0
	,@action_repeat_period_minutes = 60
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -6
	,@check_name = 'Action queue failure rate is high'
	,@check_description = 'There is a large number of items that failed execution. This could indicate a problem with the action mechanism.'
	,@check_query = 'select count(*) from dbo.sqlwatch_meta_action_queue where exec_status = ''FAILED'''
	,@check_frequency_minutes = 5
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>5'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 0
	,@action_repeat_period_minutes = 60
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -7
	,@check_name = 'Disk Free % is low'
	,@check_description = 'The "Free Space %" value is lower than expected. One or more disks have less than expected free space. 
This does not mean that the disk will be full soon as it may not grow much. Please check the "days until full" value or the actual growth.
If there is a report assosiated with this check, details of the storage utilistaion should be included below.'
	,@check_query = 'select free_space_percentage
from dbo.vw_sqlwatch_report_dim_os_volume
where sql_instance = @@SERVERNAME'
	,@check_frequency_minutes = 60
	,@check_threshold_warning = '<0.1'
	,@check_threshold_critical = '<0.05'
	,@check_enabled = 1
	,@check_action_id = -9

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = 1440 --daily
	,@action_hourly_limit = 10
	,@action_template_id = -2

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -8
	,@check_name = 'One or more disk will be full soon'
	,@check_description = 'The "days until full" value is lower than expected. One or more disks will be full in few days.
If there is a report assosiated with this check, details of the storage utilistaion should be included below.'
	,@check_query = 'select days_until_full
from dbo.vw_sqlwatch_report_dim_os_volume
where sql_instance = @@SERVERNAME'
	,@check_frequency_minutes = 60
	,@check_threshold_warning = '<7'
	,@check_threshold_critical = '<3'
	,@check_enabled = 1
	,@check_action_id = -9

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = 1440 --daily
	,@action_hourly_limit = 10
	,@action_template_id = -2

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -9
	,@check_name = 'Check execution time is high'
	,@check_description = 'There are checks that take over 1 second to execute on average. 
Make sure checks tare lightweight and do not use up lots of resources and time. 
Checks are executed in series, in a single threaded cursor and not parralel. This means that 10 checks taking 1 second each will in total take 10 seconds to run.
Each check should not take more than few miliseconds to run.
You can view average check execution time in [dbo].[vw_sqlwatch_report_dim_check] and individual runs in [dbo].[sqlwatch_logger_check]'
	,@check_query = 'SELECT max([avg_check_exec_time_ms])
FROM [dbo].[vw_sqlwatch_report_dim_check]
where sql_instance = @@SERVERNAME'
	,@check_frequency_minutes = 15
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>1000'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = 1440 --daily
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -10
	,@check_name = 'Checks are failling'
	,@check_description = 'There is one or more failed checks.
You can view last_check_status in [dbo].[vw_sqlwatch_report_dim_check] and individual runs in [dbo].[sqlwatch_logger_check]'
	,@check_query = 'select count(*) 
from [dbo].[vw_sqlwatch_report_dim_check]
where sql_instance = @@SERVERNAME 
and last_check_status = ''CHECK ERROR'''
	,@check_frequency_minutes = 5
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>0'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = 1440 --daily
	,@action_hourly_limit = 10
	,@action_template_id = -1

--------------------------------------------------------------------------------------
exec [dbo].[usp_sqlwatch_user_add_check]
	 @check_id = -11
	,@check_name = 'Queued actions have not been processed'
	,@check_description = 'There is one or more actions that have not been processed for more than 1 hour. This could indicate problems with the action processing mechanism.'
	,@check_query = 'select count(*)
from [dbo].[sqlwatch_meta_action_queue]
where exec_status is null
and time_queued < dateadd(hour,-1,SYSDATETIME())'
	,@check_frequency_minutes = 15
	,@check_threshold_warning = NULL
	,@check_threshold_critical = '>0'
	,@check_enabled = 1
	,@check_action_id = -2

	,@action_every_failure = 0
	,@action_recovery = 1
	,@action_repeat_period_minutes = 1440 --daily
	,@action_hourly_limit = 10
	,@action_template_id = -1

set identity_insert [dbo].[sqlwatch_config_check] off;
enable trigger dbo.trg_sqlwatch_config_check_U on [dbo].[sqlwatch_config_check];

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
			('SQLWATCH-LOGGER-MISSING-INDEXES',	'SQLWATCH-LOGGER-INDEXES'),
			('SQLWATCH-INTERNAL-META-CONFIG',	'SQLWATCH-INTERNAL-CONFIG')

select @sql = @sql + convert(varchar(max),' if (select name from msdb.dbo.sysjobs where name = ''' + old_job + ''') is not null
	and (select name from msdb.dbo.sysjobs where name = ''' + new_job + ''') is null
	begin
		exec msdb.dbo.sp_update_job @job_name=N''' + old_job + ''', @new_name=N''' + new_job + '''
	end;')
from #jobrename

exec ( @sql )



USE [$(DatabaseName)];

exec dbo.[usp_sqlwatch_config_set_default_agent_jobs]

exec msdb.dbo.sp_start_job @job_name = 'SQLWATCH-INTERNAL-CONFIG'