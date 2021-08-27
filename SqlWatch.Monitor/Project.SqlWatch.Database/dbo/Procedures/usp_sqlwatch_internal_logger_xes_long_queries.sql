CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_xes_long_queries]
	@data xml,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin

	set nocount on;

	--declare @target_data_char nvarchar(max),
	--		@target_data_xml xml,
				
	--		@session_name nvarchar(64) = 'SQLWATCH_long_queries',
	--		@store_event_data smallint = dbo.ufn_sqlwatch_get_config_value(23,null),

	--		@event_data utype_event_data;

	----quit if the collector is switched off
	--if (select collect 
	--	from [dbo].[sqlwatch_config_snapshot_type]
	--	where snapshot_type_id = @snapshot_type_id
	--	) = 0
	--	begin
	--		return;
	--	end;

	--	select
	--		 attach_activity_id=left(xed.event_data.value('(action[@name="attach_activity_id"]/value )[1]', 'varchar(255)'),36) --discard sequence
	--		,[event_time]=xed.event_data.value('(@timestamp)[1]', 'datetime')
	--		,[event_name]=xed.event_data.value('(@name)[1]', 'varchar(255)')
	--		,[session_id]=isnull(xed.event_data.value('(action[@name="session_id"]/value)[1]', 'bigint'),0)
	--		,[database_name]=xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)')
	--		,[cpu_time]=xed.event_data.value('(data[@name="cpu_time"]/value)[1]', 'bigint')
	--		,[physical_reads]=xed.event_data.value('(data[@name="physical_reads"]/value)[1]', 'bigint')
	--		,[logical_reads]=xed.event_data.value('(data[@name="logical_reads"]/value)[1]', 'bigint')
	--		,[writes]=xed.event_data.value('(data[@name="writes"]/value)[1]', 'bigint')
	--		,[spills]=xed.event_data.value('(data[@name="spills"]/value)[1]', 'bigint')
	--		,[offset_start]=xed.event_data.value('(data[@name="offset"]/value)[1]', 'bigint')
	--		,[offset_end]=xed.event_data.value('(data[@name="offset_end"]/value)[1]', 'bigint')
	--		,[username]=xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)')
	--		,[client_hostname]=xed.event_data.value('(action[@name="client_hostname"]/value)[1]', 'varchar(255)')
	--		,[client_app_name]=xed.event_data.value('(action[@name="client_app_name"]/value)[1]', 'varchar(255)')
	--		,[duration_ms]=xed.event_data.value('(data[@name="duration"]/value)[1]', 'bigint')/1000
	--		,[wait_type]=xed.event_data.value('(data[@name="wait_type"]/text )[1]', 'varchar(255)')
	--		,[plan_handle] = convert(varbinary(64),'0x' + xed.event_data.value('(action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1)

	--		--for best performance, sql text exclusions could be baked into the xes so we do not even collect anything we do not want
	--		--this would require dynamic xes creation which is something I will look to do in the future
	--		,[sql_text] = dbo.ufn_sqlwatch_clean_sql_text(xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)'))
	--		,sql_instance = @sql_instance
	--		,event_data =  case when 1 = 1 then xed.event_data.query('.') else null end
	--	into #t_queries
	--	from @data.nodes('/CollectionSnapshot/XesData/row/event_data/event') as xed(event_data)

	--	create nonclustered index idx_tmp_t_queries_1 on #t_queries (sql_instance, plan_handle, [offset_start], [offset_end]);
	--	create nonclustered index idx_tmp_t_queries_2 on #t_queries (event_name, event_time, session_id, sql_instance);

	--	delete from #t_queries
	--	where plan_handle = 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
	--	or offset_start is null
	--	or offset_end is null;
								
	--	insert into dbo.[sqlwatch_logger_dm_exec_requests_long_requests] (
	--			[event_time], event_name, session_id, sqlwatch_database_id
	--		, cpu_time, physical_reads, logical_reads, writes, spills
	--		, username
	--		, client_hostname, client_app_name
	--		, duration_ms
	--		, snapshot_time, snapshot_type_id 
	--		, plan_handle
	--		, statement_start_offset
	--		, statement_end_offset
	--		, attach_activity_id
	--		, sql_instance
	--		, event_data
	--		, [sql_text]
	--		)

	--	select 
	--			tx.[event_time], tx.event_name, tx.session_id, db.sqlwatch_database_id
	--		, tx.cpu_time, tx.physical_reads, tx.logical_reads, tx.writes, tx.spills
	--		, tx.username
	--		, tx.client_hostname
	--		, client_app_name = [dbo].[ufn_sqlwatch_parse_job_name] ( tx.client_app_name, j.name, @sql_instance )
	--		, tx.duration_ms
	--		, [snapshot_time] = @snapshot_time
	--		, [snapshot_type_id] = @snapshot_type_id
	--		, tx.plan_handle
	--		, tx.[offset_start]
	--		, tx.[offset_end]
	--		, tx.attach_activity_id
	--		, tx.sql_instance
	--		, tx.event_data
	--		, tx.[sql_text]
	--	from #t_queries tx

	--	inner join dbo.sqlwatch_meta_database db
	--		on db.database_name = tx.database_name
	--		and db.sql_instance = tx.sql_instance
	--		and db.is_current = 1

	--	-- do not load queries that we arleady have
	--	left join dbo.[sqlwatch_logger_dm_exec_requests_long_requests] x
	--		on x.event_name = tx.event_name
	--		and x.event_time = tx.event_time
	--		and x.session_id = tx.session_id
	--		and x.sql_instance = tx.sql_instance

	--	left join msdb.dbo.sysjobs j
	--		on j.job_id = [dbo].[ufn_sqlwatch_parse_job_id] ( tx.client_app_name )

	--	-- exclude queries containing text that we do not want to collect or coming from an excluded host or an application
	--	left join [dbo].[sqlwatch_config_exclude_xes_long_query] ex
	--		on case when ex.sql_text is not null then tx.sql_text else '%' end like isnull(ex.sql_text,'%')
	--		and case when ex.client_app_name is not null then tx.client_app_name else '%' end like isnull(ex.client_app_name,'%')
	--		and case when ex.client_hostname is not null then tx.client_hostname else '%' end like isnull(ex.client_hostname,'%')
	--		and case when ex.username is not null then tx.username else '%' end like isnull(ex.username,'%')

	--	where ex.[exclusion_id] is null
	--	and x.event_time is null;

end;