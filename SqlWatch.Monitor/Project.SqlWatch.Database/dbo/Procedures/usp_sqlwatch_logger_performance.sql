CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_performance] AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_logger_performance]

 Description:
	Collect Performance Metrics

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski:	Initial Version
	1.1		2019-11-17	- Marcin Gminski:	Exclude idle wait stats.
	1.2		2019-11-24	- Marcin Gminski:	Replace sys.databses with dbo.vw_sqlwatch_sys_databases
	1.3		2020-03-18	- Marcin Gminski,	move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
-------------------------------------------------------------------------------------------------------------------
*/


set xact_abort on

set nocount on;


declare	@product_version nvarchar(128)
declare @product_version_major decimal(10,2)
declare @product_version_minor decimal(10,2)
declare	@sql_memory_mb int
declare @os_memory_mb int
declare @memory_available int
declare @percent_idle_time real
declare @percent_processor_time real
declare @date_snapshot_current datetime2(0)
declare @date_snapshot_previous datetime2(0)

declare @snapshot_type_id tinyint = 1


declare @sql nvarchar(4000) 

		--------------------------------------------------------------------------------------------------------------
		-- detect which version of sql we are running as some dmvs are different in different versions of sql
		--------------------------------------------------------------------------------------------------------------
		set @product_version = convert(nvarchar(128),serverproperty('productversion')); --no longer needed

		select 
			 @product_version_major = [dbo].[ufn_sqlwatch_get_product_version]('major')
			,@product_version_minor = [dbo].[ufn_sqlwatch_get_product_version]('minor')

		--------------------------------------------------------------------------------------------------------------
		-- set the basics
		--------------------------------------------------------------------------------------------------------------
		select @date_snapshot_previous = max([snapshot_time])
		from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
		where snapshot_type_id = @snapshot_type_id
		and sql_instance = @@SERVERNAME
		
		exec [dbo].[usp_sqlwatch_internal_insert_header] 
			@snapshot_time_new = @date_snapshot_current OUTPUT,
			@snapshot_type_id = @snapshot_type_id
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


	begin tran
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

		insert into dbo.[sqlwatch_logger_perf_os_performance_counters] ([performance_counter_id],[instance_name], [cntr_value], [base_cntr_value],
			[snapshot_time], [snapshot_type_id], [sql_instance], [cntr_value_calculated])
		select
			 mc.[performance_counter_id]
			,instance_name = rtrim(pc.instance_name)
			,pc.cntr_value
			,base_cntr_value=bc.cntr_value
			,snapshot_time=@date_snapshot_current
			, @snapshot_type_id
			, @@SERVERNAME
			,[cntr_value_calculated] = convert(real,(
				case 
					--https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecountertype?view=netframework-4.8
					--https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancedata.countertype?view=netframework-4.8
					when mc.object_name = 'Batch Resp Statistics' then case when pc.cntr_value > prev.cntr_value then cast((pc.cntr_value - prev.cntr_value) as real) else 0 end -- delta absolute
					
					/*	65792
						An instantaneous counter that shows the most recently observed value. Used, for example, to maintain a simple count of a very large number of items or operations. 
						It is the same as NumberOfItems32 except that it uses larger fields to accommodate larger values.	*/
					when mc.cntr_type = 65792 then isnull(pc.cntr_value,0) 	
					
					/*	272696576
						A difference counter that shows the average number of operations completed during each second of the sample interval. Counters of this type measure time in ticks of the system clock. 
						This counter type is the same as the RateOfCountsPerSecond32 type, but it uses larger fields to accommodate larger values to track a high-volume number of items or operations per second, 
						such as a byte-transmission rate. Counters of this type include System\ File Read Bytes/sec.	*/
					when mc.cntr_type = 272696576 then case when (pc.cntr_value > prev.cntr_value) then (pc.cntr_value - prev.cntr_value) / cast(datediff(second,prev.snapshot_time,@date_snapshot_current) as real) else 0 end -- delta rate
					
					/*	537003264	
						This counter type shows the ratio of a subset to its set as a percentage. For example, it compares the number of bytes in use on a disk to the total number of bytes on the disk. 
						Counters of this type display the current percentage only, not an average over time. It is the same as the RawFraction32 counter type, except that it uses larger fields to accommodate larger values.	*/
					when mc.cntr_type = 537003264 then isnull(cast(100.0 as real) * pc.cntr_value / nullif(bc.cntr_value, 0),0) -- ratio

					/*	1073874176		
						An average counter that shows how many items are processed, on average, during an operation. Counters of this type display a ratio of the items processed to the number of operations completed. 
						The ratio is calculated by comparing the number of items processed during the last interval to the number of operations completed during the last interval. 
						Counters of this type include PhysicalDisk\ Avg. Disk Bytes/Transfer.	*/
					when mc.cntr_type = 1073874176 then isnull(case when pc.cntr_value > prev.cntr_value then isnull((pc.cntr_value - prev.cntr_value) / nullif(bc.cntr_value - prev.base_cntr_value, 0) / cast(datediff(second,prev.snapshot_time,@date_snapshot_current) as real), 0) else 0 end,0) -- delta ratio
				end))
		from (
			select * from sys.dm_os_performance_counters
			union all
			/*  because we are only querying sql related performance counters (as only those are exposed through sql) we do not
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
		inner join [dbo].[sqlwatch_meta_performance_counter] mc
			on mc.[object_name] = rtrim(pc.[object_name]) collate database_default
			and mc.[counter_name] = rtrim(pc.[counter_name]) collate database_default
			and mc.[sql_instance] = @@SERVERNAME

		left join [dbo].[sqlwatch_logger_perf_os_performance_counters] prev --previous
			on prev.sql_instance = @@SERVERNAME
			and prev.snapshot_type_id = @snapshot_type_id
			and prev.performance_counter_id = mc.performance_counter_id
			and prev.instance_name = rtrim(pc.instance_name) collate database_default
			and prev.snapshot_time = @date_snapshot_previous

		where sc.collect = 1
		option (recompile)

		--------------------------------------------------------------------------------------------------------------
		-- get schedulers summary
		--------------------------------------------------------------------------------------------------------------
		insert into dbo.[sqlwatch_logger_perf_os_schedulers]
			select 
				  snapshot_time = @date_snapshot_current
				, snapshot_type_id = @snapshot_type_id
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
		-- based on [msdb].[dbo].[syscollector_collection_items]
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
					sum(single_pages_kb) as single_pages_kb,
					0 as multi_pages_kb,
					sum(virtual_memory_reserved_kb) as virtual_memory_reserved_kb,
					sum(virtual_memory_committed_kb) as virtual_memory_committed_kb,
					sum(awe_allocated_kb) as awe_allocated_kb,
					sum(shared_memory_reserved_kb) as shared_memory_reserved_kb,
					sum(shared_memory_committed_kb) as shared_memory_committed_kb
				from sys.dm_os_memory_clerks mc
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
		select t.snapshot_time, t.total_kb, t.allocated_kb,  mm.sqlwatch_mem_clerk_id
			, t.[snapshot_type_id], t.[sql_instance]
		from (
			select 
				snapshot_time =@date_snapshot_current
				, total_kb=sum(mc.total_kb)
				, allocated_kb=sum(mc.single_pages_kb + mc.multi_pages_kb)
				 -- There are many memory clerks. We will log any that make up 5% of sql memory or more; less significant clerks will be lumped into an "other" bucket
				 -- this approach will save storage whilst retaining enough detail for troubleshooting. 
				 -- if you want to see more or less clerks, you can adjust it here, or even remove entirely to log all clerks
				 -- In my test enviroment, the summary of all clerks, i.e. a clerk across all nodes and addresses will give approx 87 rows, 
				 -- the below approach gives ~6 rows on average but your mileage will vary.
				, [type] = case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'OTHER' end
				, [snapshot_type_id] = @snapshot_type_id
				, [sql_instance] = @@SERVERNAME
			from @memory_clerks as mc
			outer apply 
			(	select 
					sum (mc_ta.total_kb) as total_kb_all_clerks
				from @memory_clerks as mc_ta
			) as ta
			group by mc.snapshot_time, case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'OTHER' end
		) t
		inner join [dbo].[sqlwatch_meta_memory_clerk] mm
			on mm.clerk_name = t.[type] collate database_default
			and mm.sql_instance = @@SERVERNAME
		option (recompile)					

		--------------------------------------------------------------------------------------------------------------
		-- file stats snapshot
		--------------------------------------------------------------------------------------------------------------
		insert into dbo.[sqlwatch_logger_perf_file_stats] (
			[sqlwatch_database_id]
           ,[sqlwatch_master_file_id]
		   ,[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],[num_of_writes],[num_of_bytes_written],[io_stall_write_ms],[size_on_disk_bytes]
		   ,[snapshot_time]
		   ,[snapshot_type_id]
		   ,[sql_instance]
		   
		   , [num_of_reads_delta]
		   , [num_of_bytes_read_delta]
		   , [io_stall_read_ms_delta]
		   , [num_of_writes_delta]
		   , [num_of_bytes_written_delta]
		   , [io_stall_write_ms_delta]
		   , [size_on_disk_bytes_delta]
		   , [delta_seconds]
		   )
		select 
			 sd.sqlwatch_database_id
			,mf.sqlwatch_master_file_id
			,num_of_reads = convert(real,fs.num_of_reads)
			, num_of_bytes_read = convert(real,fs.num_of_bytes_read)
			, io_stall_read_ms = convert(real,fs.io_stall_read_ms)
			, num_of_writes = convert(real,fs.num_of_writes)
			, num_of_bytes_written = convert(real,fs.num_of_bytes_written)
			, io_stall_write_ms = convert(real,fs.io_stall_write_ms)
			, size_on_disk_bytes = convert(real,fs.size_on_disk_bytes)
			, snapshot_time=@date_snapshot_current
			, @snapshot_type_id
			, @@SERVERNAME

			, [num_of_reads_delta] = convert(real,case when fs.num_of_reads > prevfs.num_of_reads then fs.num_of_reads - prevfs.num_of_reads else 0 end)
			, [num_of_bytes_read_delta] = convert(real,case when fs.num_of_bytes_read > prevfs.num_of_bytes_read then fs.num_of_bytes_read - prevfs.num_of_bytes_read else 0 end)
			, [io_stall_read_ms_delta] = convert(real,case when fs.io_stall_read_ms > prevfs.io_stall_read_ms then fs.io_stall_read_ms - prevfs.io_stall_read_ms else 0 end)
			, [num_of_writes_delta]= convert(real,case when fs.num_of_writes > prevfs.num_of_writes then fs.num_of_writes - prevfs.num_of_writes else 0 end)
			, [num_of_bytes_written_delta] = convert(real,case when fs.num_of_bytes_written > prevfs.num_of_bytes_written then fs.num_of_bytes_written - prevfs.num_of_bytes_written else 0 end)
			, [io_stall_write_ms_delta] = convert(real,case when fs.io_stall_write_ms > prevfs.io_stall_write_ms then fs.io_stall_write_ms - prevfs.io_stall_write_ms else 0 end)
			, [size_on_disk_bytes_delta] = convert(real,case when fs.size_on_disk_bytes > prevfs.size_on_disk_bytes then fs.size_on_disk_bytes - prevfs.size_on_disk_bytes else 0 end)
			, [delta_seconds] = datediff(second,@date_snapshot_previous,@date_snapshot_current)

		from sys.dm_io_virtual_file_stats (default, default) as fs
		inner join sys.master_files as f 
			on fs.database_id = f.database_id 
			and fs.[file_id] = f.[file_id]
		
		/* 2019-05-05 join on databases to get database name and create data as part of the 
		   -- doesnt this need a join on dbo.vw_sqlwatch_sys_databases instead ?
		   2019-11-24 change sys.databses to vw_sqlwatch_sys_databases */
		inner join dbo.vw_sqlwatch_sys_databases d 
			on d.database_id = f.database_id

		inner join [dbo].[sqlwatch_meta_database] sd 
			on sd.[database_name] = convert(nvarchar(128),d.[name]) collate database_default
			and sd.[database_create_date] = d.[create_date]
			and sd.sql_instance = @@SERVERNAME

		inner join [dbo].[sqlwatch_meta_master_file] mf
			on mf.sql_instance = sd.sql_instance
			and mf.sqlwatch_database_id = sd.sqlwatch_database_id
			and mf.file_name = convert(nvarchar(128),f.name) collate database_default
			and mf.[file_physical_name] = convert(nvarchar(260),f.physical_name) collate database_default

		/* 2019-10-21 pushing delta calculation to collector to improve reporting performance */
		left join [dbo].[sqlwatch_logger_perf_file_stats] (nolock) prevfs
			on prevfs.sql_instance = mf.sql_instance
			and prevfs.sqlwatch_database_id = mf.sqlwatch_database_id
			and prevfs.sqlwatch_master_file_id = mf.sqlwatch_master_file_id
			and prevfs.snapshot_type_id = @snapshot_type_id
			and prevfs.snapshot_time = @date_snapshot_previous

		left join [dbo].[sqlwatch_config_exclude_database] ed
			on d.[name] like ed.database_name_pattern collate database_default
			and ed.snapshot_type_id = @snapshot_type_id

		where ed.snapshot_type_id is null


		--------------------------------------------------------------------------------------------------------------
		/*	wait stats snapshot
			 READ ME!!

			 In previous versions we were capturing all waits that had a wait (waiting_tasks_count > 0)
			 ideally, this needs similar approach to the memory clerks where we only capture waits that actually matter.
			 or those that make up 95% of waits and ignore the noise. There is still a lot of noise despite the filter:
			 ws.waiting_tasks_count + ws.wait_time_ms + ws.max_wait_time_ms + ws.signal_wait_time_ms > 0
			 some waits are significant but have no delta over longer period of time.

			 However, the difficulty is, if we only record those that have had positive delta we may lose some waits
			 imagine the following scenario:

			 SNAPSHOT1, WAIT1,  [waiting_tasks_count] = 1,	[waiting_tasks_count_delta] = 0
			 SNAPSHOT2, WAIT1,	[waiting_tasks_count] = 2,  [waiting_tasks_count_delta] = 2-1 = 1

			 if we only record those with positive delta, we would have never captured the first occurence and thus
			 the second occurence would have had zero delta and we would not record it either. 

			 Also, because we are currently only capturing those with positive task count, there could be the following:

			 SNAPSHOT1, WAIT1,  [waiting_tasks_count] = 0,	[waiting_tasks_count_delta] = 0
			 SNAPSHOT2, WAIT1,	[waiting_tasks_count] = 100,  [waiting_tasks_count_delta] = 100 - 0 = 100

			 but, what we are going to show is this:

			 --> NOT CAPTURED:	SNAPSHOT1, WAIT1,	[waiting_tasks_count] = 0,		[waiting_tasks_count_delta] = 0
								SNAPSHOT2, WAIT1,	[waiting_tasks_count] = 100,	[waiting_tasks_count_delta] = 0

		     one way to solve is it to delete old snapshots that either have zero delta or zer0 waiting task count and 
			 only keep all values in the most recent snapshot
		*/
		--------------------------------------------------------------------------------------------------------------
		insert into [dbo].[sqlwatch_stage_perf_os_wait_stats]
		select * , @date_snapshot_current
		from sys.dm_os_wait_stats

		-- exclude idle waits and noise
		where wait_type not like 'SLEEP_%'
		and wait_type collate database_default not in (
			select wait_type 
			from [dbo].[sqlwatch_config_exclude_wait_stats]
			)

		insert into [dbo].[sqlwatch_logger_perf_os_wait_stats]
			select 
				[wait_type_id] = convert(real,ms.[wait_type_id])
				, [waiting_tasks_count] = convert(real,ws.[waiting_tasks_count])
				, [wait_time_ms] = convert(real,ws.[wait_time_ms])
				, [max_wait_time_ms] = convert(real,ws.[max_wait_time_ms])
				, [signal_wait_time_ms] = convert(real,ws.[signal_wait_time_ms])
				
				, [snapshot_time]=@date_snapshot_current
				, @snapshot_type_id, @@SERVERNAME

			, [waiting_tasks_count_delta] = convert(real,case when ws.[waiting_tasks_count] > wsprev.[waiting_tasks_count] then ws.[waiting_tasks_count] - wsprev.[waiting_tasks_count] else 0 end)
			, [wait_time_ms_delta] = convert(real,case when ws.[wait_time_ms] > wsprev.[wait_time_ms] then ws.[wait_time_ms] - wsprev.[wait_time_ms] else 0 end)
			, [max_wait_time_ms_delta] = convert(real,case when ws.[max_wait_time_ms] > wsprev.[max_wait_time_ms] then ws.[max_wait_time_ms] - wsprev.[max_wait_time_ms] else 0 end)
			, [signal_wait_time_ms_delta] = convert(real,case when ws.[signal_wait_time_ms] > wsprev.[signal_wait_time_ms] then ws.[signal_wait_time_ms] - wsprev.[signal_wait_time_ms] else 0 end)
			, [delta_seconds] = datediff(second,@date_snapshot_previous,@date_snapshot_current)
			from [dbo].[sqlwatch_stage_perf_os_wait_stats] ws
			inner join [dbo].[sqlwatch_meta_wait_stats] ms
				on ms.[wait_type] = ws.[wait_type] collate database_default
				and ms.[sql_instance] = @@SERVERNAME

			left join [dbo].[sqlwatch_stage_perf_os_wait_stats] wsprev
				on wsprev.wait_type = ws.wait_type
				and wsprev.snapshot_time = @date_snapshot_previous

			where ws.snapshot_time = @date_snapshot_current
			and ws.[waiting_tasks_count] - wsprev.[waiting_tasks_count]  > 0

		delete from [dbo].[sqlwatch_stage_perf_os_wait_stats]
		where snapshot_time < @date_snapshot_current
		--and sql_instance = @@SERVERNAME


		/*  */


commit tran
