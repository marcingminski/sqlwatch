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
-- [sqlwatch_config_exclude_database]
--------------------------------------------------------------------------------------
begin tran
	merge [dbo].[sqlwatch_config_exclude_database] as target
	using (
		select [database_name_pattern] = '%ReportServer%', [snapshot_type_id] = 3
		union all
		select 'msdb',3
		union all
		select 'master',3
		union all
		--exclude index stats and histogram collection from tempdb:
		select 'tempdb',14
		union all
		select 'tempdb',15
		union all
		--exclude tempdb from table size collector:
		select 'tempdb',22
		union all
		select 'model', 22
		) as source

	on target.[database_name_pattern]  = source.[database_name_pattern]
	and target.[snapshot_type_id] = source.[snapshot_type_id]

	when not matched then
		insert ([database_name_pattern], [snapshot_type_id])
		values (source.[database_name_pattern], source.[snapshot_type_id]);
commit tran

--------------------------------------------------------------------------------------
-- [sqlwatch_config_include_index_histogram]
--------------------------------------------------------------------------------------
begin tran
	merge [dbo].[sqlwatch_config_include_index_histogram] as target
	using (
		select	[object_name_pattern]	= '%.dbo.table%',
				[index_name_pattern]	= '%'
		) as source
	on target.[object_name_pattern] = source.[object_name_pattern]
	and target.[index_name_pattern] = source.[index_name_pattern]

	when not matched then 
		insert ([object_name_pattern], [index_name_pattern])
		values (source.[object_name_pattern], source.[index_name_pattern]);
commit tran

--------------------------------------------------------------------------------------
-- sqlwatch_config_exclude_xes_long_query
--------------------------------------------------------------------------------------
begin tran
	merge sqlwatch_config_exclude_xes_long_query as target
	using (
		select	
			[statement] = null,
			[sql_text] = null,
			[username] = null,
			[client_hostname] = null,
			[client_app_name] = 'DatabaseMail%'
		) as source
on isnull(source.[statement],'') = isnull(target.[statement],'')
and isnull(source.[sql_text],'') = isnull(target.[sql_text],'')
and isnull(source.[username],'') = isnull(target.[username],'')
and isnull(source.[client_hostname],'') = isnull(target.[client_hostname],'')
and isnull(source.[client_app_name],'') = isnull(target.[client_app_name],'')

when not matched then
	insert ([statement], [sql_text], [username], [client_hostname], [client_app_name])
	values (source.[statement], source.[sql_text], source.[username], source.[client_hostname], source.[client_app_name]);
commit tran

--------------------------------------------------------------------------------------
-- sqlwatch_config_exclude_wait_stats
--------------------------------------------------------------------------------------
declare @waits_exclusion table ([wait_type] [nvarchar](60))

insert into @waits_exclusion ([wait_type])

-- reference https://github.com/microsoft/tigertoolbox/blob/master/Waits-and-Latches/view_Waits.sql
select [value]
from ufn_sqlwatch_split_string ('RESOURCE_QUEUE,SQLTRACE_INCREMENTAL_FLUSH_SLEEP,
SP_SERVER_DIAGNOSTICS_SLEEP,SOSHOST_SLEEP,SP_PREEMPTIVE_SERVER_DIAGNOSTICS_SLEEP,QDS_PERSIST_TASK_MAIN_LOOP_SLEEP,
QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP,LOGMGR_QUEUE,CHECKPOINT_QUEUE,REQUEST_FOR_DEADLOCK_SEARCH,XE_TIMER_EVENT,
BROKER_TASK_STOP,CLR_MANUAL_EVENT,CLR_AUTO_EVENT,DISPATCHER_QUEUE_SEMAPHORE,FT_IFTS_SCHEDULER_IDLE_WAIT,BROKER_TO_FLUSH,
XE_DISPATCHER_WAIT,XE_DISPATCHER_JOIN,MSQL_XP,WAIT_FOR_RESULTS,CLR_SEMAPHORE,LAZYWRITER_SLEEP,SLEEP_TASK,
SLEEP_SYSTEMTASK,SQLTRACE_BUFFER_FLUSH,WAITFOR,BROKER_EVENTHANDLER,TRACEWRITE,FT_IFTSHC_MUTEX,BROKER_RECEIVE_WAITFOR, 
ONDEMAND_TASK_QUEUE,DBMIRROR_EVENTS_QUEUE,DBMIRRORING_CMD,BROKER_TRANSMITTER,SQLTRACE_WAIT_ENTRIES,SLEEP_BPOOL_FLUSH,SQLTRACE_LOCK,
DIRTY_PAGE_POLL,HADR_FILESTREAM_IOMGR_IOCOMPLETION, 
WAIT_XTP_OFFLINE_CKPT_NEW_LOG',DEFAULT)

union

-- reference https://www.sqlskills.com/blogs/paul/capturing-wait-statistics-period-time/
select [value] 
from ufn_sqlwatch_split_string ('BROKER_RECEIVE_WAITFOR,BROKER_TRANSMITTER,CHKPT, CXCONSUMER, EXECSYNC,FSAGENT,  
KSOURCE_WAKEUP, MEMORY_ALLOCATION_EXT, ONDEMAND_TASK_QUEUE, PARALLEL_REDO_DRAIN_WORKER,PARALLEL_REDO_LOG_CACHE, 
PARALLEL_REDO_TRAN_LIST, PARALLEL_REDO_WORKER_SYNC, PARALLEL_REDO_WORKER_WAIT_WORK,PREEMPTIVE_XE_GETTARGETSTATE, 
PWAIT_ALL_COMPONENTS_INITIALIZED, PWAIT_DIRECTLOGCONSUMER_GETNEXT, QDS_ASYNC_QUEUE, QDS_SHUTDOWN_QUEUE, 
REDO_THREAD_PENDING_WORK, RESOURCE_QUEUE, SERVER_IDLE_CHECK,SLEEP_DBSTARTUP,SLEEP_DCOMSTARTUP, 
SLEEP_MASTERDBREADY,SLEEP_MASTERMDREADY, SLEEP_MASTERUPGRADED, SLEEP_MSDBSTARTUP, SLEEP_TEMPDBSTARTUP, 
SNI_HTTP_ACCEPT, SOS_WORK_DISPATCHER, SQLTRACE_INCREMENTAL_FLUSH_SLEEP, SQLTRACE_WAIT_ENTRIES, WAITFOR_TASKSHUTDOWN, 
WAIT_XTP_RECOVERY, WAIT_XTP_HOST_WAIT, WAIT_XTP_CKPT_CLOSE',DEFAULT)

begin tran
	merge dbo.sqlwatch_config_exclude_wait_stats as target
	using (
			select distinct [wait_type] = rtrim(ltrim(replace(replace(s.[wait_type],char(10),''),char(13),''))) 
			from @waits_exclusion s
			) as source
	on source.[wait_type] = target.[wait_type]
	when not matched then
		insert ([wait_type])
		values (source.[wait_type]);
commit tran
