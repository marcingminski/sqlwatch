CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_data_metadata_snapshot_xml]
	@metadata nvarchar(50),
	@metadata_xml xml output,
	@debug bit = 0
AS

set nocount on;

declare @sql nvarchar(max),
		@prep_sql nvarchar(max),
		@sql_header nvarchar(max),
		@product_version nvarchar(128),
		@product_version_major decimal(10,2),
		@product_version_minor decimal(10,2),
		@sql_version smallint,
		@parameters nvarchar(128);

select 
	 @product_version_major = [dbo].[ufn_sqlwatch_get_product_version]('major')
	,@product_version_minor = [dbo].[ufn_sqlwatch_get_product_version]('minor')
	,@sql_version = dbo.ufn_sqlwatch_get_sql_version();

	set @parameters  = N'@metadata nvarchar(50), @xmlout xml output';
	
	set @sql_header=N'select @xmlout = (
		select snapshot_header = (
			select 
			snapshot_time = GETUTCDATE()
			, meta_data = @metadata
			, sql_instance = @@SERVERNAME
			for xml raw, type
		)
		,
	';

	if @metadata = 'sys_jobs'
		begin
			set @sql = N'
				sys_jobs = (
						select sj.job_id
							, job_name=name
							, date_created
							, ss.step_name
							, ss.step_id
							, ss.step_uid
						from msdb.dbo.sysjobs sj
							inner join msdb.dbo.sysjobsteps ss
							on sj.job_id = ss.job_id
						for xml raw, type
					)
			';
		end;

	else if @metadata = 'sys_indexes'
		begin
			set @prep_sql = N'
				declare @indexes table (
					index_name nvarchar(128), 
					index_id int,
					index_type_desc nvarchar(128),
					[table_name] nvarchar(512),
					[database_name] nvarchar(128)
				);

				insert into @indexes
				exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] @exclude_tempdb = 1, @command = ''
				USE [?];
					select 
						isnull(ix.name,object_name(ix.object_id))
						, ix.index_id
						, ix.type_desc
						, s.name + ''''.'''' + t.name
						, database_name = DB_NAME()
					from sys.indexes ix with (nolock)
					inner join sys.tables t with (nolock)
						on t.[object_id] = ix.[object_id]
					inner join sys.schemas s with (nolock)
						on s.[schema_id] = t.[schema_id]
					where objectproperty( ix.object_id, ''''IsMSShipped'''' ) = 0
					'';
			';

			set @sql = N'
				sys_indexes = (
				select 
					  t.index_name
					, t.index_id
					, t.index_type_desc
					, t.table_name
					, d.database_name
					, d.database_create_date
				from @indexes t
				inner join dbo.vw_sqlwatch_sys_databases d
					on d.[database_name] = t.[database_name]
				for xml raw, type
				)
			';
		end
		
	--else if @metadata = 'sys_missing_indexes'
	--	begin
	--		set @prep_sql = N'
	--			declare @indexes table (
	--				[database_name] nvarchar(128),
	--				[table_name] nvarchar(512),
	--				[equality_columns] nvarchar(4000),
	--				[inequality_columns] nvarchar(4000),
	--				[included_columns] nvarchar(4000),
	--				[statement] nvarchar(4000),
	--				[index_handle] int
	--			);

	--			insert into @indexes (
	--				database_name
	--				, table_name
	--				, equality_columns
	--				, inequality_columns
	--				, included_columns
	--				, statement
	--				, index_handle
	--				)
	--			exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] @exclude_tempdb = 1, @command = ''
	--				use [?];
	--				select
	--					[database_name] = DB_NAME(),
	--					[table_name] = s.name + ''''.'''' + t.name,
	--					[equality_columns] ,
	--					[inequality_columns] ,
	--					[included_columns] ,
	--					[statement] ,
	--					id.[index_handle]
	--				from sys.dm_db_missing_index_details id
	--				inner join sys.tables t
	--					on t.object_id = id.object_id
	--				inner join sys.schemas s
	--					on t.schema_id = s.schema_id
	--				where objectproperty( id.object_id, ''''IsMSShipped'''' ) = 0
	--			''
	--		'
	--		set @sql = N'
	--			sys_missing_indexes = (
	--				select
	--					d.database_name,
	--					d.database_create_date,
	--					i.[table_name],
	--					i.[equality_columns] ,
	--					i.[inequality_columns] ,
	--					i.[included_columns] ,
	--					i.[statement] ,
	--					i.[index_handle]
	--				from @indexes i
	--				inner join dbo.vw_sqlwatch_sys_databases d
	--					on d.database_name = i.database_name
	--				for xml raw, type
	--			)
	--		'
	--	end;

	else if @metadata = 'sys_tables'
		begin
			set @prep_sql = N'
					declare @tables table (
						[TABLE_CATALOG] [nvarchar](128) not null,
						[TABLE_NAME] nvarchar(512) not null
						);

					insert into @tables
					exec [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb] @exclude_tempdb = 1, @command = ''
					USE [?];
						select 
							 TABLE_CATALOG = DB_NAME()
							,TABLE_NAME = s.name + ''''.'''' + t.name
						from sys.tables t with (nolock) 
						inner join sys.schemas s with (nolock) 
						on t.schema_id = s.schema_id
						where t.is_ms_shipped = 0
					'';
			';

			set @sql = N'
					sys_tables = (
					select 
						 [TABLE_CATALOG]
						,[TABLE_TYPE] = ''BASE TABLE''
						,[TABLE_NAME]
						,d.database_create_date
					from @tables t
					inner join dbo.vw_sqlwatch_sys_databases d
					on d.name = t.[TABLE_CATALOG]
					for xml raw, type
					--for xml path (''row''), root(''sys_tables''), ELEMENTS XSINIL, type
					)
			';
		end;

	else if @metadata = 'meta_server'
		begin
			set @sql = N'
				meta_server = (
					select [physical_name] = convert(sysname,SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''))
						, [servername] = convert(sysname,@@SERVERNAME)
						, [service_name] = convert(sysname,@@SERVICENAME)
						, [local_net_address] = convert(varchar(50),local_net_address)
						, [local_tcp_port] = convert(varchar(50),local_tcp_port)
						, [utc_offset_minutes] = DATEDIFF(mi, GETUTCDATE(), GETDATE())
						, [sql_version] = @@VERSION
						, [sql_instance] = @@SERVERNAME
					from sys.dm_exec_connections where session_id = @@spid
					for xml raw, type
					)
				';
		end;

	else if @metadata = 'sys_databases'
		begin
			set @sql = N'
				sys_databases = (
					select [database_name]
						, [database_create_date]
						, [is_auto_close_on]
						, [is_auto_shrink_on]
						, [is_auto_update_stats_on]
						, [user_access]
						, [state]
						, [snapshot_isolation_state]
						, [is_read_committed_snapshot_on] 
						, [recovery_model]
						, [page_verify_option] 
					from dbo.vw_sqlwatch_sys_databases
					for xml raw, type
				)
			';
		end;

	else if @metadata = 'sys_master_files'
		begin
			set @sql = N'
				sys_master_files = (
					select 	mf.database_id
						,mf.[file_id]
						,mf.[type]
						,mf.[physical_name]
						,mf.[name]
						,db.database_name
						,db.database_create_date
					from sys.master_files mf
					inner join dbo.vw_sqlwatch_sys_databases db
						on db.database_id = mf.database_id
					for xml raw, type
					)
			';
		end;

	--else if @metadata = 'sys_procedures'
	--	begin
	--		set @sql = N'
	--			sys_procedures = (
	--				select distinct
	--					[procedure_name]=object_schema_name(ps.object_id, ps.database_id) + ''.'' + object_name(ps.object_id, ps.database_id),
	--					d.[database_name],
	--					d.database_create_date
	--				from sys.dm_exec_procedure_stats ps
	--				inner join dbo.vw_sqlwatch_sys_databases d
	--					on d.database_id = ps.database_id
	--				where ps.type = ''P''
	--				and objectproperty( ps.object_id, ''IsMSShipped'' ) = 0
	--				for xml raw, type
	--				)
	--		'
	--	end;

	else if @metadata = 'dm_os_memory_clerks'
		begin
			set @sql = N'
				dm_os_memory_clerks = (
					select distinct type
					from sys.dm_os_memory_clerks
					for xml raw, type
					)
			';
		end;

	else if @metadata = 'dm_os_wait_stats'
		begin
			set @sql = N'
				dm_os_wait_stats = (
					select distinct wait_type
					from sys.dm_os_wait_stats
					for xml raw, type
					)
			';
		end;

	else if @metadata = 'dm_os_performance_counters'
		begin
			set @sql = N'
				dm_os_performance_counters = (
					select * from (
						select distinct 
							object_name = rtrim(object_name),
							counter_name = rtrim(counter_name),
							cntr_type
						from sys.dm_os_performance_counters
						union all
						select
							object_name = ''Win32_PerfFormattedData_PerfOS_Processor'',
							counter_name = ''Processor Time %'',
							cntr_type = 65792
						union all
						select
							object_name = ''Win32_PerfFormattedData_PerfOS_Processor'',
							counter_name = ''Idle Time %'',
							cntr_type = 65792	
					) x
					for xml raw, type
				)
			';
		end;

	else if @metadata = 'dm_exec_text_query_plan'
		begin
			set @prep_sql = N'
				select top 1000
					query_hash
					, query_plan_hash
					, statement_start_offset
					, statement_end_offset
					, plan_handle
				into #t
				from sys.dm_exec_query_stats qs (nolock)
				where qs.last_execution_time > dateadd(minute,-62,getdate())
				and qs.query_hash <> 0x0000000000000000
				and last_worker_time > (total_worker_time / execution_count)
				order by (total_worker_time / execution_count) desc
			';

			set @sql = N'
				dm_exec_text_query_plan = (
					select distinct
						query_hash = convert(varchar(128),t.query_hash,1)
						, query_plan_hash = convert(varchar(128),t.query_plan_hash ,1)
						, p.query_plan
					from #t t

					inner join #t qs
						on qs.query_hash = t.query_hash
						and qs.query_plan_hash = t.query_plan_hash
						and qs.statement_start_offset = t.statement_start_offset
						and qs.statement_end_offset = t.statement_end_offset

					outer apply (
						select top 1 plan_handle, statement_start_offset, statement_end_offset
						from #t
						where query_plan_hash = t.query_plan_hash
					) h

					outer apply (
							select top 1 query_plan
							from sys.dm_exec_text_query_plan (h.plan_handle, h.statement_start_offset, h.statement_end_offset)
						) p

					for xml raw, type
				)
			'
		end;

	--else if @metadata = 'sys_configurations'
	--	begin
	--		set @sql = N'
	--			sys_configurations = (
	--				select 
	--					[configuration_id]
	--					 , [name]
	--					 , [value]
	--					 , [value_in_use]
	--					 , [description]
	--				from dbo.vw_sqlwatch_sys_configurations
	--				for xml raw, type
	--			)
	--		'
	--	end;


	if @sql <> ''
		begin
			set @sql = @sql_header + @sql;
			set @sql+= N'
				for xml path (''MetaDataSnapshot'')
			)
			option (keep plan);';

			if @prep_sql is not null
				begin
					set @sql=@prep_sql + @sql;
				end;

			if @debug = 1
				begin
					select sql = @sql;
				end;

			exec sp_executesql @sql,
				@parameters, 
				@metadata = @metadata,
				@xmlout = @metadata_xml output;
		end;