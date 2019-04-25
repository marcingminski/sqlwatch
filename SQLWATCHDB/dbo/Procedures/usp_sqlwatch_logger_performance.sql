CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_performance] AS
set nocount on;
set transaction isolation level read uncommitted;

declare	@product_version nvarchar(128)
declare @product_version_major decimal(10,2)
declare @product_version_minor decimal(10,2)
declare	@sql_memory_mb int
declare @os_memory_mb int
declare @memory_available int
declare @percent_idle_time real
declare @percent_processor_time real
declare @date_snapshot_current datetime
declare @date_snapshot_previous datetime


declare @sql nvarchar(4000) 

		--------------------------------------------------------------------------------------------------------------
		-- detect which version of sql we are running as some dmvs are different in different versions of sql
		--------------------------------------------------------------------------------------------------------------
		set @product_version = convert(nvarchar(128),serverproperty('productversion')); --no longer needed

		select 
			 @product_version_major = [dbo].[ufn_sqlwatch_get_product_version]('major')
			,@product_version_minor = [dbo].[ufn_sqlwatch_get_product_version]('minor')

		--------------------------------------------------------------------------------------------------------------
		-- get available memory on the server
		--------------------------------------------------------------------------------------------------------------
		select @sql_memory_mb = convert(int,value) from sys.configurations where name = 'max server memory (mb)'

		if @product_version_major < 11
			begin
				--sql < 2012
				exec sp_executesql N'select @osmemorymb=physical_memory_in_bytes/1024/1024  from sys.dm_os_sys_info', N'@osmemorymb int out', @os_memory_mb out
			end
		else
			begin
				exec sp_executesql N'select @osmemorymb=physical_memory_kb/1024 from sys.dm_os_sys_info', N'@osmemorymb int out', @os_memory_mb out
			end

		/* is this a bug? sql_memory_mb twice? and the os_memory_mb is not being used at all?
			this shuould union sql_memory_mb and os_memory_mb but it does not */
		select @memory_available=min(memory_available) from (
			select memory_available=@sql_memory_mb
			union all
			select memory_available=@sql_memory_mb
		) m

		--------------------------------------------------------------------------------------------------------------
		-- set the basics
		--------------------------------------------------------------------------------------------------------------
		select @date_snapshot_previous = max([snapshot_time])
		from [dbo].[sqlwatch_logger_snapshot_header]
		where snapshot_type_id = 1
		and sql_instance = @@SERVERNAME
		
		set @date_snapshot_current = getutcdate();
		insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
		values (@date_snapshot_current, 1)		
		--------------------------------------------------------------------------------------------------------------
		-- 1. get cpu
		--------------------------------------------------------------------------------------------------------------
		select 
				--original PR https://github.com/marcingminski/sqlwatch/commit/b8a8a5bbaf134dcd6afb4d5b9fef13e052a5c164
				--by https://github.com/marcingminski/sqlwatch/commits?author=sporri
				@percent_processor_time=ProcessUtilization
			,	@percent_idle_time=SystemIdle
		FROM ( 
				SELECT SystemIdle=record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int'), 
					ProcessUtilization=record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int')
				FROM ( 
					SELECT TOP 1 CONVERT(xml, record) AS [record] 
					FROM sys.dm_os_ring_buffers WITH (NOLOCK)
					WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' collate database_default
					AND record LIKE N'%<SystemHealth>%' collate database_default
					ORDER BY [timestamp] DESC
					) AS x 
				) AS y
		OPTION (RECOMPILE);

		--------------------------------------------------------------------------------------------------------------
		-- 2. get perfomance counters
		-- this is where it gets interesting. there are several types of performance counters identified by the cntr_type
		-- depending on the type, we may have to calculate deltas or deviation from the base.

		-- cntr_type description from: 
		--	https://blogs.msdn.microsoft.com/psssql/2013/09/23/interpreting-the-counter-values-from-sys-dm_os_performance_counters/
		--  https://rtpsqlguy.wordpress.com/2009/08/11/sys-dm_os_performance_counters-explained/

		-- 65792 -> this counter value shows the last observed value directly. no calculation required.
		-- 537003264 and 1073939712 -> this is similar to the above 65792 but we must divide the results by the base
		--------------------------------------------------------------------------------------------------------------

		insert into dbo.[sqlwatch_logger_perf_os_performance_counters]
		select
			 pc.[object_name]
			,pc.instance_name
			,pc.counter_name
			,pc.cntr_value
			,base_cntr_value=bc.cntr_value
			,pc.cntr_type
			,snapshot_time=@date_snapshot_current
			, 1
			, @@SERVERNAME
		from (
			select * from sys.dm_os_performance_counters
			union all
			/*  becuase we are only querying sql related performance counters (as only those are exposed through sql) we do not
				capture os performance counters such as cpu - hence we captured cpu from ringbuffer and now are going to 
				make them look like real counter (othwerwise i would have to make up a name) */
			select 
				 [object_name] = 'win32_perfformatteddata_perfos_processor'
				,[counter_name] = 'Processor Time %'
				,[instance_name] = 'sql'
				,[cntr_value] = @percent_processor_time
				,[cntr_type] = 65792
			union all
			select 
				 [object_name] = 'win32_perfformatteddata_perfos_processor'
				,[counter_name] = 'Idle Time %'
				,[instance_name] = '_total'
				,[cntr_value] = @percent_idle_time
				,[cntr_type] = 65792
			union all
			select 
				 [object_name] = 'win32_perfformatteddata_perfos_processor'
				,[counter_name] = 'Processor Time %'
				,[instance_name] = 'system'
				,[cntr_value] = (100-@percent_idle_time-@percent_processor_time)
				,[cntr_type] = 65792
			) pc
		inner join dbo.[sqlwatch_config_performance_counters] sc
		on rtrim(pc.[object_name]) like '%' + sc.[object_name] collate database_default
			and pc.counter_name = sc.counter_name collate database_default
			and (
				rtrim(pc.instance_name) = sc.instance_name collate database_default
				or	(
					sc.instance_name = '<* !_total>' collate database_default
					and rtrim(pc.instance_name) <> '_total' collate database_default
					)
				)
			outer apply (
						select pc2.cntr_value
						from sys.dm_os_performance_counters as pc2
						where pc2.cntr_type = 1073939712
							and pc2.[object_name] = pc.[object_name] collate database_default
							and pc2.instance_name = pc.instance_name collate database_default
							and rtrim(pc2.counter_name) = sc.base_counter_name collate database_default
						) bc
		where sc.collect = 1
		option (recompile)

		--------------------------------------------------------------------------------------------------------------
		-- get schedulers summary
		--------------------------------------------------------------------------------------------------------------
		insert into dbo.[sqlwatch_logger_perf_os_schedulers]
			select 
				  snapshot_time = @date_snapshot_current
				, snapshot_type_id = 1
				, scheduler_count = sum(case when is_online = 1 then 1 else 0 end)
				, [idle_scheduler_count] = sum(convert(int,is_idle))
				, current_tasks_count = sum(current_tasks_count)
				, runnable_tasks_count = sum(runnable_tasks_count)

				, preemptive_switches_count = sum(convert(bigint,preemptive_switches_count))
				, context_switches_count = sum(convert(bigint,context_switches_count))
				, idle_switches_count = sum(convert(bigint,context_switches_count))

				, current_workers_count = sum(current_workers_count)
				, active_workers_count = sum(active_workers_count)
				, work_queue_count = sum(work_queue_count)
				, pending_disk_io_count = sum(pending_disk_io_count)
				, load_factor = sum(load_factor)

				, yield_count = sum(convert(bigint,yield_count))

				, failed_to_create_worker = sum(convert(int,failed_to_create_worker))

				/* 2016 onwards only */
				, total_cpu_usage_ms = null --sum(convert(bigint,total_cpu_usage_ms))
				, total_scheduler_delay_ms = null --sum(convert(bigint,total_scheduler_delay_ms))

				, @@SERVERNAME
			from sys.dm_os_schedulers
			where scheduler_id < 255
			and status = 'VISIBLE ONLINE' collate database_default

		--------------------------------------------------------------------------------------------------------------
		-- get process memory
		--------------------------------------------------------------------------------------------------------------
		insert into dbo.[sqlwatch_logger_perf_os_process_memory]
		select snapshot_time=@date_snapshot_current, * , 1, @@SERVERNAME
		from sys.dm_os_process_memory

		--------------------------------------------------------------------------------------------------------------
		-- get sql memory. dynamic again based on sql version
		--------------------------------------------------------------------------------------------------------------
		declare @dm_os_memory_clerks table (
			[type] varchar(60),
			memory_node_id smallint,
			single_pages_kb bigint,
			multi_pages_kb bigint,
			virtual_memory_reserved_kb bigint,
			virtual_memory_committed_kb bigint,
			awe_allocated_kb bigint,
			shared_memory_reserved_kb bigint,
			shared_memory_committed_kb bigint
		)
		if @product_version_major < 11
			begin
				insert into @dm_os_memory_clerks
				exec sp_executesql N'
				select 
					type,
					memory_node_id as memory_node_id,
					-- see comment in the sys.dm_os_memory_nodes query (above) for more info on 
					-- [single_pages_kb] and [multi_pages_kb]. 
					sum(single_pages_kb) as single_pages_kb,
					0 as multi_pages_kb,
					sum(virtual_memory_reserved_kb) as virtual_memory_reserved_kb,
					sum(virtual_memory_committed_kb) as virtual_memory_committed_kb,
					sum(awe_allocated_kb) as awe_allocated_kb,
					sum(shared_memory_reserved_kb) as shared_memory_reserved_kb,
					sum(shared_memory_committed_kb) as shared_memory_committed_kb
				from sys.dm_os_memory_clerks
				group by type, memory_node_id
				option (recompile)
				'
			end
		else
			begin
				insert into @dm_os_memory_clerks
				exec sp_executesql N'
				select 
					type,
					memory_node_id as memory_node_id,
					-- see comment in the sys.dm_os_memory_nodes query (above) for more info on 
					-- [single_pages_kb] and [multi_pages_kb]. 
					sum(pages_kb) as single_pages_kb,
					0 as multi_pages_kb,
					sum(virtual_memory_reserved_kb) as virtual_memory_reserved_kb,
					sum(virtual_memory_committed_kb) as virtual_memory_committed_kb,
					sum(awe_allocated_kb) as awe_allocated_kb,
					sum(shared_memory_reserved_kb) as shared_memory_reserved_kb,
					sum(shared_memory_committed_kb) as shared_memory_committed_kb
				from sys.dm_os_memory_clerks
				group by type, memory_node_id
				option (recompile)
			'
			end

		declare @memory_clerks table (
			[type] varchar(60),
			memory_node_id smallint,
			single_pages_kb bigint,
			multi_pages_kb bigint,
			virtual_memory_reserved_kb bigint,
			virtual_memory_committed_kb bigint,
			awe_allocated_kb bigint,
			shared_memory_reserved_kb bigint,
			shared_memory_committed_kb bigint,
			snapshot_time datetime,
			total_kb bigint
		)
		insert into @memory_clerks
		select 
			mc.[type], mc.memory_node_id, mc.single_pages_kb, mc.multi_pages_kb, mc.virtual_memory_reserved_kb, 
			mc.virtual_memory_committed_kb, mc.awe_allocated_kb, mc.shared_memory_reserved_kb, mc.shared_memory_committed_kb, 
			snapshot_time = @date_snapshot_current, 
			cast (mc.single_pages_kb as bigint) 
				+ mc.multi_pages_kb 
				+ (case when type <> 'MEMORYCLERK_SQLBUFFERPOOL' collate database_default then mc.virtual_memory_committed_kb else 0 end) 
				+ mc.shared_memory_committed_kb as total_kb
		from @dm_os_memory_clerks as mc

		insert into dbo.[sqlwatch_logger_perf_os_memory_clerks]
		select 
			snapshot_time =@date_snapshot_current,
			total_kb=sum(mc.total_kb), 
			allocated_kb=sum(mc.single_pages_kb + mc.multi_pages_kb),
			--ta.total_kb_all_clerks, 
			--mc.total_kb / convert(decimal, ta.total_kb_all_clerks) as percent_total_kb,
			sum(ta.total_kb_all_clerks) as total_kb_all_clerks,
			-- there are many memory clerks. we'll chart any that make up 5% of sql memory or more; less significant clerks will be lumped into an "other" bucket
			graph_type=case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'other' end
			,memory_available=@memory_available
			, 1
			, @@SERVERNAME
		from @memory_clerks as mc
		-- use a self-join to calculate the total memory allocated for each time interval
		join 
		(
			select 
				snapshot_time = @date_snapshot_current, 
				sum (mc_ta.total_kb) as total_kb_all_clerks
			from @memory_clerks as mc_ta
			group by mc_ta.snapshot_time
		) as ta on (mc.snapshot_time = ta.snapshot_time)
		group by mc.snapshot_time, case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'other' end
		--order by snapshot_time
		option (recompile)					

		delete from @memory_clerks

		--------------------------------------------------------------------------------------------------------------
		-- file stats snapshot
		--------------------------------------------------------------------------------------------------------------
		insert into dbo.[sqlwatch_logger_perf_file_stats]
		select 
			db_name (f.database_id) as [database_name], f.name as logical_file_name, f.type_desc, 
			cast (case
			when left (ltrim (f.physical_name), 2) = '\\' 
					then left (ltrim (f.physical_name), charindex ('\', ltrim (f.physical_name), charindex ('\', ltrim (f.physical_name), 3) + 1) - 1)
				when charindex ('\', ltrim(f.physical_name), 3) > 0 
					then upper (left (ltrim (f.physical_name), charindex ('\', ltrim (f.physical_name), 3) - 1))
				else f.physical_name
			end as varchar(255)) as logical_disk, 
			fs.num_of_reads, fs.num_of_bytes_read, fs.io_stall_read_ms, fs.num_of_writes, fs.num_of_bytes_written, 
			fs.io_stall_write_ms, fs.size_on_disk_bytes,
			snapshot_time=@date_snapshot_current
			, 1
			, @@SERVERNAME
		from sys.dm_io_virtual_file_stats (default, default) as fs
		inner join sys.master_files as f on fs.database_id = f.database_id and fs.[file_id] = f.[file_id]
		--------------------------------------------------------------------------------------------------------------
		-- wait stats snapshot
		--------------------------------------------------------------------------------------------------------------
		insert into [dbo].[sqlwatch_logger_perf_os_wait_stats]
		select [wait_type], [waiting_tasks_count], [wait_time_ms],[max_wait_time_ms], [signal_wait_time_ms], [snapshot_time]=@date_snapshot_current, 1, @@SERVERNAME
		from sys.dm_os_wait_stats
		where waiting_tasks_count + wait_time_ms + max_wait_time_ms + signal_wait_time_ms > 0

		--------------------------------------------------------------------------------------------------------------
		-- XE waits
		-- https://docs.microsoft.com/en-us/sql/relational-databases/extended-events/use-the-system-health-session
		-- by default, the following WAITS are logged into the default system_health session:
		--
		--	The callstack, sql_text, and session_id for any sessions that have waited on latches (or other interesting resources) for > 15 seconds.
		--	The callstack, sql_text, and session_id for any sessions that have waited on locks for > 30 seconds.
		--	The callstack, sql_text, and session_id for any sessions that have waited for a long time for preemptive waits. The duration varies by wait type. A preemptive wait is where SQL Server is waiting for external API calls. 
		--
		--------------------------------------------------------------------------------------------------------------
		if @product_version_major >= 11
			begin
	

				declare @filename varchar(8000)
				--declare @utcdatediff int = datediff(minute,getutcdate(),getdate())
				--declare @rowcount int = 0
	
				--select @filename= convert(xml,[target_data]).value('(/EventFileTarget/File/@name)[1]', 'varchar(8000)')
				--from sys.dm_xe_session_targets
				--where [target_name] = 'event_file' 
				--and [event_session_address] = (
				--	select [address]
				--	from sys.dm_xe_sessions 
				--	where [name] = 'system_health'
				--	);

				--select [event_xml] = convert(xml,[event_data])
				--, [event_time] = dateadd(mi,@utcdatediff,convert(xml,[event_data]).value('(/event/@timestamp)[1]', 'datetime'))
				--, [object_name]
				--into #xe 
				--from sys.fn_xe_file_target_read_file(@filename, null, null, null)
				--where [object_name] in ('--wait_info','sp_server_diagnostics_component_result')

				--insert into [dbo].[sql_perf_mon_snapshot_header]
				--values (@date_snapshot_current, 6)	

				--insert into [dbo].[logger_perf_xes_waits]
				--select
				--	[event_time],
				--	[session_id] = event_xml.value('(/event/action[@name="session_id"]/value)[1]', 'int'),
				--	[wait_type] = event_xml.value('(/event/data/text)[1]', 'varchar(255)'), 
				--	[duration] = event_xml.value('(/event/data/value)[3]', 'bigint'), 
				--	[signal_duration] = event_xml.value('(/event/data/value)[4]', 'bigint'), 
				--	[wait_resource]	= event_xml.value('(/event/data/value)[5]', 'varchar(255)'), 
				--	[query]	= event_xml.value('(/event/action[@name="sql_text"]/value)[1]', 'varchar(max)'),
				--	[snapshot_time] = @date_snapshot_current,
				--	[snapshot_type_id] = 6
				--from #xe t
				--where [object_name] = 'wait_info'
				--and [event_time] > (select isnull(max([event_time]),'1970-01-01') from [dbo].[logger_perf_xes_waits])

				--insert into [dbo].[logger_perf_xes_query_processing]
				--select 
				--	[event_time],
				--	[max_workers] = event_xml.value('(/event/data/value/queryProcessing/@maxWorkers)[1]','bigint'),
				--	[workers_created] = event_xml.value('(/event/data/value/queryProcessing/@workersCreated)[1]','bigint'),
				--	[idle_workers] = event_xml.value('(/event/data/value/queryProcessing/@workersIdle)[1]','bigint'),
				--	[pending_tasks] = event_xml.value('(/event/data/value/queryProcessing/@pendingTasks)[1]','bigint'),
				--	[unresolvable_deadlocks] = event_xml.value('(/event/data/value/queryProcessing/@hasUnresolvableDeadlockOccurred)[1]','int'),
				--	[deadlocked_scheduler] = event_xml.value('(/event/data/value/queryProcessing/@hasDeadlockedSchedulersOccurred)[1]','int'),
				--	[snapshot_time] = @date_snapshot_current,
				--	[snapshot_type_id] = 1
				--from #xe 
				--where [object_name] = 'sp_server_diagnostics_component_result'
				--and [event_time] > (select isnull(max([event_time]),'1970-01-01') from [dbo].[logger_perf_xes_query_processing])
				--and convert(xml, [event_xml]).value('(/event/data/text)[1]','varchar(255)') = 'QUERY_PROCESSING'

				--insert into [dbo].[logger_perf_xes_iosubsystem]
				--select
				--	[event_time],
				--	[io_latch_timeouts] = event_xml.value('(/event/data/value/ioSubsystem/@ioLatchTimeouts)[1]','bigint'),
				--	[total_long_ios] = event_xml.value('(/event/data/value/ioSubsystem/@totalLongIos)[1]','bigint'),
				--	[longest_pending_request_file] = event_xml.value('(/event/data/value/ioSubsystem/longestPendingRequests/pendingRequest/@filePath)[1]','varchar(255)'),
				--	[longest_pending_request_duration] = event_xml.value('(/event/data/value/ioSubsystem/longestPendingRequests/pendingRequest/@duration)[1]','bigint'),
				--	[snapshot_time] = @date_snapshot_current,
				--	[snapshot_type_id] = 1
				--from #xe 
				--where [object_name] = 'sp_server_diagnostics_component_result'
				--and [event_time] > (select isnull(max([event_time]),'1970-01-01') from [dbo].[logger_perf_xes_iosubsystem])
				--and convert(xml, [event_xml]).value('(/event/data/text)[1]','varchar(255)') = 'IO_SUBSYSTEM'
			end
go