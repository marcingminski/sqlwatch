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
if (select count(*) from [dbo].[sqlwatch_config_exclude_database]) = 0
	begin
		 --exclude collecting missing indexes from ReportServer and system databases:
		insert into [dbo].[sqlwatch_config_exclude_database] ([database_name_pattern], [snapshot_type_id])
		values  ('%ReportServer%',3),
				('msdb',3),
				('master',3),
		--exclude index stats and histogram collection from tempdb:
				('tempdb',14),
				('tempdb',15)
	end


if (select count(*) from [dbo].[sqlwatch_config_include_index_histogram]) = 0
	begin
		insert into [dbo].[sqlwatch_config_include_index_histogram] ([object_name_pattern],[index_name_pattern])
		values ('%.dbo.table%','%')
	end


if (select count(*) from dbo.sqlwatch_config_exclude_xes_long_query) = 0
	begin
		insert into dbo.sqlwatch_config_exclude_xes_long_query (
			[statement]
           ,[sql_text]
           ,[username]
           ,[client_hostname]
           ,[client_app_name])
		values (null,null,null,null,'DatabaseMail%')
	end


if (select count(*) from dbo.sqlwatch_config_exclude_wait_stats) = 0
	begin
		declare @waits_exclusion table (
			[wait_type] [nvarchar](60)
			)


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


		insert into dbo.sqlwatch_config_exclude_wait_stats ([wait_type])
		select distinct rtrim(ltrim(replace(replace(s.[wait_type],char(10),''),char(13),''))) 
		from @waits_exclusion s
		left join dbo.sqlwatch_config_exclude_wait_stats t
			on s.[wait_type] = t.[wait_type]
		where t.[wait_type] is null

	end