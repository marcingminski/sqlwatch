CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_data_collection_snapshot_xml]
	@snapshot_type_id tinyint,
	@snapshot_data_xml xml output,
	@debug bit = 0
as
begin

	set nocount on;

	declare @sql nvarchar(max),
			@prep_sql nvarchar(max),
			@sql_header nvarchar(max),
			@parameters nvarchar(128),
			@sql_version smallint,
			@product_version nvarchar(128),
			@product_version_major decimal(10,2),
			@product_version_minor decimal(10,2);

	set @sql_version = dbo.ufn_sqlwatch_get_sql_version();
	set @product_version_major = [dbo].[ufn_sqlwatch_get_product_version]('major');
	set @product_version_minor = [dbo].[ufn_sqlwatch_get_product_version]('minor');
	set @parameters  = '@snapshot_type_id smallint, @xmlout xml output';
	
	set @sql = N'';

	set @sql_header=N'select @xmlout = (
		select snapshot_header = (
			select 
			snapshot_time = GETUTCDATE()
			, snapshot_type_id = @snapshot_type_id
			, sql_instance = @@SERVERNAME
			, timezoneoffset = DATEPART(TZOffset, SYSDATETIMEOFFSET())
			for xml raw, type
		)
		,
	';

	--return as xml:
	if @snapshot_type_id = 1
		begin
			set @prep_sql = N'
					declare @percent_idle_time real, @percent_processor_time real;

					select top 1 
							@percent_processor_time = percent_processor_time
						,	@percent_idle_time = percent_idle_time
					from [dbo].[sqlwatch_stage_ring_buffer] with (nolock)
					order by snapshot_time desc
					option (keep plan);
					';

			set @sql+= N'
					dm_os_performance_counters = (
						select 
							  [object_name] = convert(nvarchar(128),rtrim(pc.[object_name]))
							, [counter_name] = convert(nvarchar(128),rtrim(pc.[counter_name]))
							, [instance_name] = convert(nvarchar(128),rtrim(pc.[instance_name]))
							, pc.cntr_value
							, pc.cntr_type
							, pc.base_counter_name
							, pc.base_cntr_value
						from (
							select
							  [object_name]=rtrim(pc1.[object_name])
							, counter_name=rtrim(pc1.[counter_name])
							, instance_name=rtrim(pc1.[instance_name])
							, pc1.cntr_value
							, pc1.cntr_type
							, base_counter_name = rtrim(sc.base_counter_name)
							, base_cntr_value = bc.cntr_value
							from sys.dm_os_performance_counters pc1 with (nolock)

							inner join dbo.[sqlwatch_config_performance_counters] sc with (nolock)
								on rtrim(pc1.[object_name]) like ''%'' + sc.[object_name] collate database_default
								and rtrim(pc1.counter_name) = sc.counter_name collate database_default
								and (
									rtrim(pc1.instance_name) = sc.instance_name collate database_default
									or	(
										sc.instance_name = ''<* !_Total>'' collate database_default
										and rtrim(pc1.instance_name) <> ''_Total'' collate database_default
										)
									)

							outer apply (
										select pcb.cntr_value
										from sys.dm_os_performance_counters pcb with (nolock)
										where pcb.cntr_type = 1073939712
											and pcb.[object_name] = pc1.[object_name] collate database_default
											and pcb.instance_name = pc1.instance_name collate database_default
											and pcb.counter_name = sc.base_counter_name collate database_default
										) bc

							where sc.collect = 1
							and pc1.cntr_type <> 1073939712

							union all
							/*  because we are only querying sql related performance counters (as only those are exposed through sql) we do not
								capture os performance counters such as cpu - hence we captured cpu from ringbuffer and now are going to 
								make them look like real counter (othwerwise i would have to make up a name) */
							select 
								[object_name] = ''Win32_PerfFormattedData_PerfOS_Processor''
								,[counter_name] = ''Processor Time %''
								,[instance_name] = ''sql''
								,[cntr_value] = @percent_processor_time
								,[cntr_type] = 65792
								,base_counter_name = null
								,base_cntr_value = null

							union all
							select 
								[object_name] = ''Win32_PerfFormattedData_PerfOS_Processor''
								,[counter_name] = ''Idle Time %''
								,[instance_name] = ''_Total                                                                                                                          ''
								,[cntr_value] = @percent_idle_time
								,[cntr_type] = 65792
								,base_counter_name = null
								,base_cntr_value = null

							union all
							select 
								[object_name] = ''Win32_PerfFormattedData_PerfOS_Processor''
								,[counter_name] = ''Processor Time %''
								,[instance_name] = ''system''
								,[cntr_value] = (100-@percent_idle_time-@percent_processor_time)
								,[cntr_type] = 65792
								,base_counter_name = null
								,base_cntr_value = null
							) pc
					
							where cntr_value is not null
							for xml raw, type
						)
						,dm_os_process_memory = (
							select 
								 [physical_memory_in_use_kb] 
								,[large_page_allocations_kb] 
								,[locked_page_allocations_kb] 
								,[total_virtual_address_space_kb] 
								,[virtual_address_space_reserved_kb] 
								,[virtual_address_space_committed_kb] 
								,[virtual_address_space_available_kb] 
								,[page_fault_count] 
								,[memory_utilization_percentage]
								,[available_commit_limit_kb] 
								,[process_physical_memory_low]
								,[process_virtual_memory_low] 
							from sys.dm_os_process_memory with (nolock)
							for xml raw, type
						)
						,dm_os_schedulers = (
							select 
								 [scheduler_count] = sum(case when is_online = 1 then 1 else 0 end)
								,[idle_scheduler_count] = sum(convert(int,is_idle))
								,[current_tasks_count] = sum(current_tasks_count)
								,[runnable_tasks_count] = sum(runnable_tasks_count)
					
								,[preemptive_switches_count] = sum(convert(bigint,preemptive_switches_count))
								,[context_switches_count] = sum(convert(bigint,context_switches_count))
								,[idle_switches_count] = sum(convert(bigint,context_switches_count))
								,[current_workers_count] = sum(current_workers_count)
								,[active_workers_count] = sum(work_queue_count)

								,[work_queue_count] = sum(work_queue_count)
								,[pending_disk_io_count] = sum(pending_disk_io_count)
								,[load_factor] = sum(load_factor)
								,[yield_count] = sum(convert(bigint,yield_count))

								,[failed_to_create_worker] = sum(convert(int,failed_to_create_worker))

							' + case when @sql_version >= 2016 
							then 
								N'
								, [total_cpu_usage_ms] = sum(convert(bigint,total_cpu_usage_ms))
								, [total_scheduler_delay_ms] = sum(convert(bigint,total_scheduler_delay_ms))
								' 
							else 
								N'
								, [total_cpu_usage_ms] = null
								, [total_scheduler_delay_ms] = null
								' 
							end + N'
						from sys.dm_os_schedulers with (nolock)
						where scheduler_id < 255
						and status = ''VISIBLE ONLINE'' collate database_default
						for xml raw, type
						)
						,dm_os_wait_stats = (
						select
							ws.wait_type,
							ws.waiting_tasks_count,
							ws.wait_time_ms,
							ws.max_wait_time_ms,
							ws.signal_wait_time_ms
						from sys.dm_os_wait_stats ws with (nolock)
						where ws.wait_type not like ''SLEEP_%''
						for xml raw, type
						)
						,dm_os_memory_clerks = (
							select 
								 type
								,memory_node_id = memory_node_id
								' + case 
									when @product_version_major < 11.00 
								then 
									N', single_pages_kb = sum(single_pages_kb)'
								else 
									N', single_pages_kb = sum(pages_kb)' 
								end + N'
								, multi_pages_kb = 0
								, virtual_memory_reserved_kb = sum(virtual_memory_reserved_kb)
								, virtual_memory_committed_kb = sum(virtual_memory_committed_kb)
								, awe_allocated_kb = sum(awe_allocated_kb)
								, shared_memory_reserved_kb = sum(shared_memory_reserved_kb)
								, shared_memory_committed_kb = sum(shared_memory_committed_kb)
							from sys.dm_os_memory_clerks mc with (nolock)
							group by type, memory_node_id
							for xml raw, type
						)
						,dm_io_virtual_file_stats = (
							select 
								 d.[database_name]
								,d.database_create_date
								,fs.[num_of_reads] 
								,fs.[num_of_bytes_read]
								,fs.[io_stall_read_ms] 
								,fs.[num_of_writes] 
								,fs.[num_of_bytes_written]
								,fs.[io_stall_write_ms] 
								,fs.[size_on_disk_bytes] 
								,f.physical_name
								,file_name = f.name
							from sys.dm_io_virtual_file_stats (default, default) as fs
							inner join sys.master_files as f  with (nolock)
								on fs.database_id = f.database_id 
								and fs.[file_id] = f.[file_id]
							inner join dbo.vw_sqlwatch_sys_databases d 
								on d.database_id = f.database_id
							for xml raw, type
						)
			';
		end;
	
	else if @snapshot_type_id = 2
		begin
			set @prep_sql = N'
				declare @space_used table (
					[database_name] sysname
					,database_size_bytes bigint
					,[unallocated_space_bytes] bigint
					,reserved_bytes bigint
					,data_bytes bigint
					,index_size_bytes bigint
					,unused_bytes bigint
					,unallocated_extent_page_count bigint
					,allocated_extent_page_count bigint
					,version_store_reserved_page_count bigint
					,user_object_reserved_page_count bigint
					,internal_object_reserved_page_count bigint
					,mixed_extent_page_count bigint
					,total_log_size_in_bytes bigint
					,used_log_space_in_bytes bigint
				);

				insert into @space_used
				exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] ''
				USE [?]
					declare  @id	int			
							,@type	character(2) 
							,@pages	bigint
							,@dbname sysname
							,@dbsize bigint
							,@logsize bigint
							,@reservedpages  bigint
							,@usedpages  bigint
							,@rowCount bigint

							,@unallocated_extent_page_count bigint
							,@allocated_extent_page_count bigint
							,@version_store_reserved_page_count bigint
							,@user_object_reserved_page_count bigint
							,@internal_object_reserved_page_count bigint
							,@mixed_extent_page_count bigint

							,@total_log_size_in_bytes bigint
							,@used_log_space_in_bytes bigint;

					select 
						 @unallocated_extent_page_count = sum(a.unallocated_extent_page_count) 
						,@allocated_extent_page_count = sum(a.allocated_extent_page_count) 
						,@version_store_reserved_page_count = sum(a.version_store_reserved_page_count) 
						,@user_object_reserved_page_count = sum(a.user_object_reserved_page_count) 
						,@internal_object_reserved_page_count = sum(a.internal_object_reserved_page_count) 
						,@mixed_extent_page_count = sum(a.mixed_extent_page_count)
					from sys.dm_db_file_space_usage a;
				
					--exclude database snapshots
					if exists (select 1 from sys.databases where name = DB_NAME()
					and source_database_id is null)
						begin
							select 
								@total_log_size_in_bytes = [total_log_size_in_bytes],
								@used_log_space_in_bytes = [used_log_space_in_bytes]
							from sys.dm_db_log_space_usage
						end;

					select 
						  @dbsize = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))
						, @logsize = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))
						from dbo.sysfiles;

					select 
						@reservedpages = sum(a.total_pages),
						@usedpages = sum(a.used_pages),
						@pages = sum(
								case
									-- XML-Index and FT-Index and semantic index internal tables are not considered "data", but is part of "index_size"
									when it.internal_type IN (202,204,207,211,212,213,214,215,216,221,222,236) then 0
									when a.type <> 1 and p.index_id < 2 then a.used_pages
									when p.index_id < 2 then a.data_pages
									else 0
								end
							)
					from sys.partitions p join sys.allocation_units a on p.partition_id = a.container_id
						left join sys.internal_tables it on p.object_id = it.object_id;

					select 
						 database_name = db_name()
						,database_size_bytes = (@dbsize + @logsize) * 8192
						,[unallocated_space_bytes] = case when @dbsize >= @reservedpages then @dbsize - @reservedpages else 0 end * 8192
						,reserved_bytes = @reservedpages * 8192
						,data_bytes = @pages * 8192 
						,index_size_bytes = (@usedpages - @pages) * 8192
						,unused_bytes = (@reservedpages - @usedpages) * 8192
						,unallocated_extent_page_count = @unallocated_extent_page_count
						,allocated_extent_page_count = @allocated_extent_page_count
						,version_store_reserved_page_count = @version_store_reserved_page_count
						,user_object_reserved_page_count = @user_object_reserved_page_count
						,internal_object_reserved_page_count = @internal_object_reserved_page_count
						,mixed_extent_page_count = @mixed_extent_page_count
						,total_log_size_in_bytes = @total_log_size_in_bytes
						,used_log_space_in_bytes = @used_log_space_in_bytes;
						'';'
						;
			set @sql+= N'
					 database_space_usage = (
						select
							 d.[database_name]
							,d.[database_create_date]
							,u.database_size_bytes 
							,u.[unallocated_space_bytes]
							,u.reserved_bytes 
							,u.data_bytes 
							,u.index_size_bytes 
							,u.unused_bytes 
							,u.unallocated_extent_page_count 
							,u.allocated_extent_page_count 
							,u.version_store_reserved_page_count 
							,u.user_object_reserved_page_count 
							,u.internal_object_reserved_page_count 
							,u.mixed_extent_page_count 
							,u.total_log_size_in_bytes 
							,u.used_log_space_in_bytes 
						from @space_used u
						inner join dbo.vw_sqlwatch_sys_databases d
						on d.name = u.database_name
						for xml raw, type
						--for xml path (''row''), root(''database_space_usage''), ELEMENTS XSINIL, type
					)';
		end;
	
	else if @snapshot_type_id = 3
		begin
			set @sql = N'
				missing_index_stats = (
					select 
						igs.[last_user_seek],
						igs.[unique_compiles], 
						igs.[user_seeks], 
						igs.[user_scans], 
						igs.[avg_total_user_cost], 
						igs.[avg_user_impact],
						ig.index_handle,
						mi.equality_columns,
						db.database_name,
						db.database_create_date,
						table_name = PARSENAME(statement,2) + ''.'' + PARSENAME(statement,1)
					from sys.dm_db_missing_index_groups ig with (nolock)

					inner join sys.dm_db_missing_index_group_stats igs with (nolock)
						on igs.group_handle = ig.index_group_handle 

					inner join sys.dm_db_missing_index_details mi with (nolock)
						on ig.index_handle = mi.index_handle

					inner join dbo.vw_sqlwatch_sys_databases db
						on db.name = PARSENAME(statement,3)
					for xml raw, type
				)
			'
		end;

	else if @snapshot_type_id = 14
		begin
			set @prep_sql = N'
				declare @index_stats table (
					used_page_count real,
					user_seeks real,
					user_scans real,
					user_lookups real,
					user_updates real,
					last_user_seek datetime2(3),
					last_user_scan datetime2(3),
					last_user_lookup datetime2(3),
					last_user_update datetime2(3),
					stats_date datetime2(3),
					is_disabled bit,
					partition_id bigint,
					partition_count bigint,
					database_id int,
					index_name nvarchar(512),
					table_name nvarchar(512),
					index_id int,
					type_desc nvarchar(60)
				)

				insert into @index_stats
				exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] @exclude_tempdb = 1, @command = ''
					USE [?]

					declare @timelimit datetime2(3);
					set @timelimit = dateadd(minute,-375,getdate());
					select 
						[used_page_count] = convert(real,ps.[used_page_count]),
						[user_seeks] = convert(real,ixus.[user_seeks]),
						[user_scans] = convert(real,ixus.[user_scans]),
						[user_lookups] = convert(real,ixus.[user_lookups]),
						[user_updates] = convert(real,ixus.[user_updates]),
						ixus.[last_user_seek],
						ixus.[last_user_scan],
						ixus.[last_user_lookup],
						ixus.[last_user_update],
						[stats_date]=STATS_DATE(ix.object_id, ix.index_id),
						[is_disabled]=ix.is_disabled,
						partition_id = -1,
						[partition_count] = ps.partition_count,
						dbs.database_id,
						index_name = case when ix.type_desc = ''''HEAP'''' then s.name + ''''.'''' + t.name else ix.name end,
						table_name = s.name + ''''.'''' + t.name,
						ix.index_id,
						ix.type_desc
					from sys.dm_db_index_usage_stats ixus with (nolock)

					inner join sys.databases dbs with (nolock)
						on dbs.database_id = ixus.database_id
						and dbs.name = DB_NAME()

					inner join sys.indexes ix  with (nolock)
						on ix.index_id = ixus.index_id
						and ix.object_id = ixus.object_id

					/*	to reduce size of the index stats table, we are going to aggreagte partitions into tables.
						from daily database management and DBA point of view, we care more about overall index stats rather than
						individual partitions.	*/
					inner join (
						select 
							[object_id]
							, [index_id]
							, [used_page_count]=sum([used_page_count])
							, [partition_count]=count(*)
						from sys.dm_db_partition_stats with (nolock)
						group by [object_id], [index_id]
						) ps 
						on  ps.[object_id] = ix.[object_id]
						and ps.[index_id] = ix.[index_id]

					inner join sys.tables t  with (nolock)
						on t.[object_id] = ix.[object_id]

					inner join sys.schemas s  with (nolock)
						on s.[schema_id] = t.[schema_id]

					where objectproperty( t.object_id, ''''IsMSShipped'''' ) = 0

					--only those that had some use:
					and ixus.[user_seeks] + ixus.[user_scans] + ixus.[user_lookups] + ixus.[user_updates] > 0

					--and only those that used since last pull
					and (
						last_user_seek > @timelimit
						or last_user_scan > @timelimit
						or last_user_lookup > @timelimit
						or last_user_update > @timelimit
						)
				''
			';

			set @sql = N'
				index_usage_stats = (
					select 
						used_page_count,
						user_seeks,
						user_scans,
						user_lookups,
						user_updates,
						last_user_seek,
						last_user_scan,
						last_user_lookup,
						last_user_update,
						stats_date,
						is_disabled,
						partition_id,
						partition_count,
						database_name,
						database_create_date,
						index_name,
						table_name,
						s.index_id,
						s.type_desc
					from @index_stats s
					inner join dbo.vw_sqlwatch_sys_databases d
					on d.database_id = s.database_id
					for xml raw, type
				)
			'
		end;

	else if @snapshot_type_id = 16
		begin
			set @sql = N'
				agent_job_history = (
					select j.*
					from (
						select 
							sj.job_id
							, job_name = sj.name
							, job_create_date = sj.date_created
							, instance_id
							, step_id
							, step_name
							, run_datetime = msdb.dbo.agent_datetime(jh.run_date, jh.run_time)
							, run_duration = ((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + run_duration%100 ))
							, run_date = msdb.dbo.agent_datetime(jh.run_date, jh.run_time)
							, run_time
							, [run_date_utc] = dateadd(minute,(datepart(TZOFFSET,SYSDATETIMEOFFSET()))*-1,msdb.dbo.agent_datetime(jh.run_date, jh.run_time))
							, run_status
						from msdb.dbo.sysjobhistory jh
							inner join msdb.dbo.sysjobs sj
								on jh.job_id = sj.job_id
						--successful jobs only:
						where run_status = 1
						and step_id > 0					
					) j
					where run_datetime > dateadd(minute,-11,getdate())
					for xml raw, type
				)
			';
		end;

	else if @snapshot_type_id = 22
		begin
			set @prep_sql = N'
				declare @table_stats table (
					table_name nvarchar(512),
					database_name sysname,
					database_create_date datetime2(3),
					row_count real,
					total_pages real,
					used_pages real,
					data_compression bit
				);

				insert into @table_stats
				exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] @exclude_tempdb = 1, @command = ''
				USE [?]
					select 
						table_name = s.name + ''''.'''' + t.name,
						database_name = sdb.name,
						database_create_date = sdb.create_date,
						row_count = convert(real,avg(p.rows)),
						total_pages = convert(real,sum(a.total_pages)),
						used_pages = convert(real,sum(a.used_pages)),
						[data_compression] = max(case when i.index_id = 0 then p.[data_compression] else 0 end)
					from sys.tables t
					inner join sys.indexes i on t.object_id = i.object_id
					inner join sys.partitions p on i.object_id = p.object_id AND i.index_id = p.index_id
					inner join sys.allocation_units a on p.partition_id = a.container_id
					inner join sys.schemas s on t.schema_id = s.schema_id
					inner join sys.databases sdb on sdb.name = DB_NAME()
					where t.is_ms_shipped = 0
					group by s.name, t.name, sdb.name, sdb.create_date;
				'';
			';

			set @sql+= N'
				
				table_space_usage = (
					select
						ts.table_name ,
						d.database_name ,
						d.database_create_date ,
						ts.row_count ,
						ts.total_pages ,
						ts.used_pages ,
						ts.data_compression
					from @table_stats ts
					inner join dbo.vw_sqlwatch_sys_databases d
					on d.database_name = ts.database_name
					for xml raw, type
					--for xml path (''row''), root(''table_space_usage''), ELEMENTS XSINIL, type
				)
			'
		end;

	else if @snapshot_type_id = 26
		begin
			set @sql = N'
				sys_configurations = (
					select 
						v.configuration_id
						, v.value
						, v.value_in_use
						, v.description
						, v.name
					from dbo.vw_sqlwatch_sys_configurations v
					for xml raw, type
				)
			'
		end;

	else if @snapshot_type_id = 27
		begin
			set @sql = N'
				dm_exec_procedure_stats = (
					select top 10000
						[cached_time],
						[cached_time_utc] = [dbo].[ufn_sqlwatch_convert_local_to_utctime]([cached_time]),
						[last_execution_time],
						[last_execution_time_utc] = [dbo].[ufn_sqlwatch_convert_local_to_utctime]([last_execution_time]),
						[execution_count],
						[total_worker_time],
						[last_worker_time],
						[min_worker_time],
						[max_worker_time],
						[total_physical_reads],
						[last_physical_reads],
						[min_physical_reads],
						[max_physical_reads],
						[total_logical_writes],
						[last_logical_writes],
						[min_logical_writes],
						[max_logical_writes],
						[total_logical_reads],
						[last_logical_reads],
						[min_logical_reads],
						[max_logical_reads],
						[total_elapsed_time],
						[last_elapsed_time],
						[min_elapsed_time],
						[max_elapsed_time], 
						d.database_name,
						d.database_create_date,
						procedure_name = object_schema_name(ps.object_id, ps.database_id) + ''.'' + object_name(ps.object_id, ps.database_id),
						type
					from sys.dm_exec_procedure_stats ps
					inner join dbo.vw_sqlwatch_sys_databases d
						on ps.database_id = d.database_id
					where last_execution_time >= dateadd(minute,-62,getdate())
					order by ps.total_worker_time desc
					for xml raw, type
				)
			';
		end;

	else if @snapshot_type_id = 28
		begin
			set @sql = N'
				dm_exec_query_stats = (
					select top 10000
						query_hash = convert(varchar(128),qs.query_hash,1)				
						
						,query_plan_hash_distinct_count = count(distinct query_plan_hash)
						,plan_handle_distinct_count = count(distinct plan_handle)
						,sql_handle_distinct_count = count(distinct sql_handle)

						,query_plan_hash_total_count = count(query_plan_hash)
						,plan_handle_total_count = count(plan_handle)
						,sql_handle_total_count = count(sql_handle)

						,[first_creation_time] = min(creation_time)
						,[last_creation_time] = max(creation_time)

						,last_execution_time = max(qs.last_execution_time)
						,[last_execution_time_utc] = max([dbo].[ufn_sqlwatch_convert_local_to_utctime](qs.[last_execution_time]))

						,execution_count = sum(qs.execution_count)
						,total_worker_time = sum(qs.total_worker_time)
						,min_worker_time = min(qs.min_worker_time)
						,max_worker_time = max(qs.max_worker_time)
						,total_physical_reads = sum(qs.total_physical_reads)
						,min_physical_reads = min(qs.min_physical_reads)
						,max_physical_reads = max(qs.max_physical_reads)
						,total_logical_writes = sum(qs.total_logical_writes)
						,min_logical_writes = min(qs.min_logical_writes)
						,max_logical_writes = max(qs.max_logical_writes)
						,total_logical_reads = sum(qs.total_logical_reads)
						,min_logical_reads = min(qs.min_logical_reads)
						,max_logical_reads = max(qs.max_logical_reads)
						,total_clr_time = sum(qs.total_clr_time)
						,min_clr_time = min(qs.min_clr_time)
						,max_clr_time = max(qs.max_clr_time)
						,total_elapsed_time = sum(qs.total_elapsed_time)
						,min_elapsed_time = min(qs.min_elapsed_time)
						,max_elapsed_time = max(qs.max_elapsed_time)
						,total_rows = sum(qs.total_rows)
						,min_rows = min(qs.min_rows)
						,max_rows = max(qs.max_rows)
						' + case when @sql_version >= 2016 then N'
							,total_dop = sum(qs.total_dop)
							,min_dop = min(qs.min_dop)
							,max_dop = max(qs.max_dop)
							,total_grant_kb = sum(qs.total_grant_kb)
							,min_grant_kb = min(qs.min_grant_kb)
							,max_grant_kb = max(qs.max_grant_kb)
							,total_used_grant_kb = sum(qs.total_used_grant_kb)
							,min_used_grant_kb = min(qs.min_used_grant_kb)
							,max_used_grant_kb = max(qs.max_used_grant_kb)
							,total_ideal_grant_kb = sum(qs.total_ideal_grant_kb)
							,min_ideal_grant_kb = min(qs.min_ideal_grant_kb)
							,max_ideal_grant_kb = max(qs.max_ideal_grant_kb)
							,total_reserved_threads = sum(qs.total_reserved_threads)
							,min_reserved_threads = min(qs.min_reserved_threads)
							,max_reserved_threads = max(qs.max_reserved_threads)
							,total_used_threads = sum(qs.total_used_threads)
							,min_used_threads = min(qs.min_used_threads)
							,max_used_threads = max(qs.max_used_threads)'
						else N'
							,total_dop=null
							,min_dop=null	
							,max_dop=null	
							,total_grant_kb=null	
							,min_grant_kb=null	
							,max_grant_kb=null	
							,total_used_grant_kb=null	
							,min_used_grant_kb=null	
							,max_used_grant_kb=null	
							,total_ideal_grant_kb=null	
							,min_ideal_grant_kb=null	
							,max_ideal_grant_kb=null	
							,total_reserved_threads=null	
							,min_reserved_threads=null	
							,max_reserved_threads=null	
							,total_used_threads=null	
							,min_used_threads=null	
							,max_used_threads=null'
						end + N'
						, sql_statement = max([dbo].[ufn_sqlwatch_get_sql_statement](text,statement_start_offset, statement_end_offset))
						, plan_generation_num = sum(plan_generation_num)
						, procedure_name = isnull(object_schema_name(t.objectid, t.dbid) + ''.'' + object_name(t.objectid, t.dbid),''Ad-Hoc Query 3FBE6AA6'')
						, d.database_name
						, d.database_create_date
					from sys.dm_exec_query_stats qs
					outer apply sys.dm_exec_sql_text(plan_handle) t

					inner join dbo.vw_sqlwatch_sys_databases d
						on d.database_id = t.dbid

					where qs.last_execution_time > dateadd(minute,-62,getdate())
					and qs.query_hash <> 0x0000000000000000
					and total_worker_time > 0

					group by 
						convert(varchar(128),qs.query_hash,1),
						isnull(object_schema_name(t.objectid, t.dbid) + ''.'' + object_name(t.objectid, t.dbid),''Ad-Hoc Query 3FBE6AA6''),
						d.database_name,
						d.database_create_date

					order by total_worker_time desc
					for xml raw, type
				)
			'
		end;

	else if @snapshot_type_id = 29
		begin
			set @sql = N'
					dm_hadr_database_replica_states = (
						select 
							 hadr_group_name = ag.name
							,ar.replica_server_name
							,ar.availability_mode
							,ar.failover_mode
							,[database_name] = dbs.name
							,rs.is_local
							,' + case when @sql_version >= 2014 then 'rs.[is_primary_replica]' else '[is_primary_replica] = null' end + '
							,rs.[synchronization_state]
							,rs.[is_commit_participant]
							,rs.[synchronization_health]
							,rs.[database_state]
							,rs.[is_suspended]
							,rs.[suspend_reason]
							,rs.[log_send_queue_size]
							,rs.[log_send_rate]
							,rs.[redo_queue_size]
							,rs.[redo_rate]
							,rs.[filestream_send_rate]
							,' + case when @sql_version > 2014 then 'rs.[secondary_lag_seconds]' else '[secondary_lag_seconds] = null' end + '
							,rs.[last_commit_time]
						from sys.dm_hadr_database_replica_states rs
						inner join sys.availability_replicas ar 
							on ar.group_id = rs.group_id
							and ar.replica_id = rs.replica_id
						inner join sys.availability_groups ag
							on ag.group_id = rs.group_id
						inner join sys.databases dbs
							on dbs.database_id = rs.database_id
						for xml raw, type
						--for xml path (''row''), root(''dm_hadr_database_replica_states''), ELEMENTS XSINIL, type
					)';
		end;

	else if @snapshot_type_id = 30
		begin
			set @prep_sql = N'
				set lock_timeout 1000;
			';
			set @sql = N'
					dm_exec_sessions = (
						select s.session_id, program_name, login_name, host_name
							, reads = case when s.session_id > 50 then reads end
							, logical_reads = case when s.session_id > 50 then logical_reads end
							, writes = case when s.session_id > 50 then writes end
							, s.status
							, cpu_time = case when s.session_id > 50 then cpu_time end
							, wait_duration_ms = sum(case when s.session_id > 50 then wt.wait_duration_ms else null end)
							, s.is_user_process
							, s.memory_usage
						from sys.dm_exec_sessions s (nolock)
						left join sys.dm_os_waiting_tasks wt (nolock)
							on wt.session_id = s.session_id
						where s.session_id <> @@SPID
						group by s.session_id, program_name, login_name, host_name, reads, logical_reads, writes, s.status, cpu_time, is_user_process, memory_usage
						for xml raw, type
					),
					dm_exec_requests = (
						select 
								r.request_id
								, r.session_id
								, start_time = case when is_reportable = 1 then start_time end
								, sql_handle = case when is_reportable = 1 then convert(varchar(255),r.sql_handle,1) end
								, plan_handle = case when is_reportable = 1 then convert(varchar(255),r.plan_handle,1) end
								, query_hash = case when is_reportable = 1 then convert(varchar(255), isnull(query_hash,[dbo].[ufn_sqlwatch_create_hash](t.text)),1) end
								, query_plan_hash = case when is_reportable = 1 then convert(varchar(255), isnull(query_plan_hash,[dbo].[ufn_sqlwatch_create_hash](p.query_plan)),1) end
								, status
								, wait_time = case when is_reportable = 1 then wait_time end
								, cpu_time = case when is_reportable = 1 then cpu_time end
								, reads = case when is_reportable = 1 then reads end
								, logical_reads = case when is_reportable = 1 then logical_reads end
								, writes = case when is_reportable = 1 then writes end
								, command = case when is_reportable = 1 then command end
								, duration_ms = case when is_reportable = 1 then datediff(ms,r.start_time,getdate()) end

								, spills
								, granted_query_memory = case when is_reportable = 1 then granted_query_memory end
								, sql_text = case when is_reportable = 1 then t.text end
								, query_plan = case when is_reportable = 1 then p.query_plan end
								, procedure_name = case when is_reportable = 1 then isnull(object_schema_name(t.objectid, t.dbid) + ''.'' + object_name(t.objectid, t.dbid),''Ad-Hoc Query 3FBE6AA6'') end
								, granted_memory_kb
								, ideal_memory_kb
								, query_cost
								, used_memory_kb
								, mg.dop
								, wait_type = case when is_reportable = 1 then r.wait_type end 
								, r.queue_id
								, is_reportable = case when is_reportable = 1 then is_reportable end
								, d.database_name 
								, d.database_create_date 
							from (
								select 
									--request data:
									session_id
									, request_id
									, start_time
									, sql_handle = case when is_reportable = 1 then sql_handle end
									, plan_handle = case when is_reportable = 1 then plan_handle end
									, statement_start_offset = case when is_reportable = 1 then statement_start_offset end
									, statement_end_offset = case when is_reportable = 1 then statement_end_offset end
									, status
									, wait_time
									, cpu_time
									, reads
									, logical_reads
									, writes
									, command
									, query_hash
									, query_plan_hash
									, granted_query_memory
									, wait_type
									, queue_id
									, database_id
									, is_reportable

								from (
									select sys.dm_exec_requests.*
										, is_reportable = case when (datediff(second,start_time,getdate()) > ' + convert(nvarchar(max), dbo.ufn_sqlwatch_get_config_value(26,null)) + ' and session_id > 50) and (bt.queue_id is not null or command not in (''RESTORE HEADERONLY'',''RESTORE LOG'',''RESTORE DATABASE'',''BACKUP LOG'', ''BACKUP DATABASE'', ''DBCC'', ''FOR'')) then 1 else 0 end
										, bt.queue_id
									from sys.dm_exec_requests (nolock) 
									left join sys.dm_broker_activated_tasks bt (nolock) 
										on bt.spid = sys.dm_exec_requests.session_id
									where sys.dm_exec_requests.session_id <> @@SPID	

									) rx

							) r

							inner join dbo.vw_sqlwatch_sys_databases d
								on d.database_id = r.database_id

							left join (
									select sut.session_id, sut.request_id, spills = sum(sut.user_objects_alloc_page_count + sut.internal_objects_alloc_page_count)
									from sys.dm_db_task_space_usage sut (nolock)
									group by sut.session_id, sut.request_id
								) su
								on su.session_id = r.session_id
								and su.request_id = r.request_id
								and r.is_reportable = 1

							left join sys.dm_exec_query_memory_grants mg (nolock)
								on mg.session_id = r.session_id
								and mg.request_id = r.request_id
								and r.is_reportable = 1

							outer apply sys.dm_exec_sql_text(r.sql_handle) t

							outer apply sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) p

							for xml raw, type
					)
			';
			--set @sql = N'
			--		dm_exec_requests = (
			--			select 
			--				  [type] = case when r.session_id > 50 then 1 else 0 end
			--				, [background] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Background'' then 1 else 0 end))
			--				, [running] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Running'' and session_id <> @@SPID then 1 else 0 end))
			--				, [runnable] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Runnable'' then 1 else 0 end))
			--				, [sleeping] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Sleeping'' then 1 else 0 end))
			--				, [suspended] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Suspended'' then 1 else 0 end))
			--				, [wait_time] = sum(convert(real,wait_time))
			--				, [cpu_time] = sum(convert(real,cpu_time))
			--				, [waiting_tasks] = isnull(sum(waiting_tasks),0)
			--				, [waiting_tasks_wait_duration_ms] = isnull(sum(wait_duration_ms),0)
			--			from sys.dm_exec_requests r (nolock)
			--			left join (
			--				-- get waiting tasks
			--				select type = case when t.session_id > 50 then 1 else 0 end
			--					, waiting_tasks = count(*)
			--					, wait_duration_ms = sum(convert(real,wait_duration_ms))
			--				from sys.dm_os_waiting_tasks t (nolock)
			--				-- TODO TO DO this filter could happen in the central repo.
			--				-- we are not going to save too much and will avoid having to resync tables
			--				where wait_type collate database_default not in (
			--					select wait_type 
			--					from dbo.sqlwatch_config_exclude_wait_stats (nolock)
			--					) 
			--				and session_id is not null 
			--				group by case when t.session_id > 50 then 1 else 0 end
			--				) t
			--			on t.type = case when r.session_id > 50 then 1 else 0 end
			--			group by case when r.session_id > 50 then 1 else 0 end
			--			for xml raw, type
			--		)
			--		,dm_exec_sessions = (
			--			select 
			--				 [type] = is_user_process
			--				,[running] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Running'' and session_id <> @@SPID then 1 else 0 end))
			--				,[sleeping] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Sleeping'' then 1 else 0 end))
			--				,[dormant] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Dormant'' then 1 else 0 end))
			--				,[preconnect] = convert(real,sum(case when isnull(status,'''') collate database_default = ''Preconnect'' then 1 else 0 end))
			--				,[cpu_time] = sum(convert(real,cpu_time))
			--				,[reads] = sum(convert(real,reads))
			--				,[writes] = sum(convert(real,writes))
			--			from sys.dm_exec_sessions (nolock)
			--			group by is_user_process
			--			for xml raw, type
			--		)';
		end;

	else if @snapshot_type_id = 32
		begin
			set @sql = N'
				agent_job_history = (
					select j.*
					from (
						select 
							sj.job_id
							, job_name = sj.name
							, job_create_date = sj.date_created
							, instance_id
							, step_id
							, step_name
							, run_datetime = msdb.dbo.agent_datetime(jh.run_date, jh.run_time)
							, run_duration = ((jh.run_duration/10000*3600 + (jh.run_duration/100)%100*60 + run_duration%100 ))
							, run_date = msdb.dbo.agent_datetime(jh.run_date, jh.run_time)
							, run_time
							, [run_date_utc] = [dbo].[ufn_sqlwatch_convert_local_to_utctime](msdb.dbo.agent_datetime(jh.run_date, jh.run_time))
							, run_status
						from msdb.dbo.sysjobhistory jh with (nolock)
							inner join msdb.dbo.sysjobs sj with (nolock)
								on jh.job_id = sj.job_id
						--failed or canceled jobs only:
						where run_status in (0,3)
						and step_id > 0					
					) j
					where run_datetime > dateadd(second,-75,getdate())
					for xml raw, type
				)
			';
		end;

	--call proc to get XES snapshots:
	if @snapshot_type_id = 6
		begin
			exec dbo.[usp_sqlwatch_internal_get_data_xes] 
				@session_name = 'SQLWATCH_waits',
				@snapshot_type_id = @snapshot_type_id,
				@event_data_xml_out = @snapshot_data_xml output;
				return;
		end;
	
	--else if @snapshot_type_id = -7
	--	begin
	--		exec dbo.[usp_sqlwatch_internal_get_data_xes] 
	--			@session_name = 'SQLWATCH_long_queries',
	--			@snapshot_type_id = @snapshot_type_id,
	--			@event_data_xml_out = @snapshot_data_xml output;
	--			return;
	--	end;
	
	else if @snapshot_type_id = 9
		begin
			exec dbo.[usp_sqlwatch_internal_get_data_xes] 
				@session_name = 'SQLWATCH_blockers',
				@snapshot_type_id = @snapshot_type_id,
				@event_data_xml_out = @snapshot_data_xml output;
				return;
		end;
	
	else if @snapshot_type_id = 10
		begin
			exec dbo.[usp_sqlwatch_internal_get_data_xes] 
				@session_name = 'system_health',
				@snapshot_type_id = @snapshot_type_id,
				@object_name = 'sp_server_diagnostics_component_result',
				@event_data_xml_out = @snapshot_data_xml output;
				return;
		end;

	else
		begin
			--if not XES snapshots or else, execute the sql create at the begining:
			if @sql <> ''
				begin
					set @sql = @sql_header + @sql;
					set @sql+= N'
						for xml path (''CollectionSnapshot'')
					)
					option (keep plan);'

					if @prep_sql is not null
						begin
							set @sql=@prep_sql + @sql;
						end;

					if @debug = 1
						begin
							select @sql;
						end

					exec sp_executesql @sql,
						@parameters, 
						@snapshot_type_id = @snapshot_type_id,
						@xmlout = @snapshot_data_xml output
				end
		end;
	return;
end;