CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_os_memory_clerks]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin
	set nocount on;

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
		total_kb bigint,
		snapshot_time datetime2(0),
		snapshot_type_id tinyint,
		sql_instance varchar(32)
	);


	declare @xml_parser_memory_clerks as [dbo].[utype_sqlwatch_sys_dm_os_memory_clerks];

	insert into @xml_parser_memory_clerks (
		[type] 
		,[memory_node_id] 
		,[single_pages_kb]
		,[multi_pages_kb] 
		,[virtual_memory_reserved_kb] 
		,[virtual_memory_committed_kb]
		,[awe_allocated_kb] 
		,[shared_memory_reserved_kb] 
		,[shared_memory_committed_kb]
	)
	select
		[type] 
		,[memory_node_id] 
		,[single_pages_kb]
		,[multi_pages_kb] 
		,[virtual_memory_reserved_kb] 
		,[virtual_memory_committed_kb]
		,[awe_allocated_kb] 
		,[shared_memory_reserved_kb] 
		,[shared_memory_committed_kb]
	from openxml (@xdoc, '/CollectionSnapshot/dm_os_memory_clerks/row',1) 
		with (
			[type] varchar(60),
			[memory_node_id] smallint,
			[single_pages_kb] bigint,
			[multi_pages_kb] bigint,
			[virtual_memory_reserved_kb] bigint,
			[virtual_memory_committed_kb] bigint,
			[awe_allocated_kb] bigint,
			[shared_memory_reserved_kb] bigint,
			[shared_memory_committed_kb] bigint
		)
	option (maxdop 1, keep plan);

	insert into @memory_clerks  (
		[type] 
		,memory_node_id 
		,single_pages_kb
		,multi_pages_kb 
		,virtual_memory_reserved_kb 
		,virtual_memory_committed_kb
		,awe_allocated_kb 
		,shared_memory_reserved_kb 
		,shared_memory_committed_kb
		,total_kb 
		,snapshot_time 
		,snapshot_type_id 
		,sql_instance 
	)
	select 
		  mc.[type]
		, mc.memory_node_id
		, mc.single_pages_kb
		, mc.multi_pages_kb
		, mc.virtual_memory_reserved_kb
		, mc.virtual_memory_committed_kb
		, mc.awe_allocated_kb
		, mc.shared_memory_reserved_kb
		, mc.shared_memory_committed_kb
		, total_kb= cast (mc.single_pages_kb as bigint) 
			+ mc.multi_pages_kb 
			+ (case when type <> 'MEMORYCLERK_SQLBUFFERPOOL' collate database_default then mc.virtual_memory_committed_kb else 0 end) 
			+ mc.shared_memory_committed_kb
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	from @xml_parser_memory_clerks as mc
	option (keep plan);

	insert into dbo.[sqlwatch_logger_dm_os_memory_clerks] (
		snapshot_time, total_kb, allocated_kb, sqlwatch_mem_clerk_id, snapshot_type_id, sql_instance
	)
	select 
		  t.snapshot_time
		, t.total_kb
		, t.allocated_kb
		, mm.sqlwatch_mem_clerk_id
		, t.[snapshot_type_id]
		, t.[sql_instance]
	from (
		select 
			  mc.snapshot_time
			, total_kb=sum(mc.total_kb)
			, allocated_kb=sum(mc.single_pages_kb + mc.multi_pages_kb)
				-- There are many memory clerks. We will log any that make up 5% of sql memory or more; less significant clerks will be lumped into an "other" bucket
				-- this approach will save storage whilst retaining enough detail for troubleshooting. 
				-- if you want to see more or less clerks, you can adjust it here, or even remove entirely to log all clerks
				-- In my test enviroment, the summary of all clerks, i.e. a clerk across all nodes and addresses will give approx 87 rows, 
				-- the below approach gives ~6 rows on average but your mileage will vary.
			, [type] = case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'OTHER' end
			, mc.snapshot_type_id
			, mc.sql_instance
		from @memory_clerks as mc
		outer apply	(	
				select 
				sum (mc_ta.total_kb) as total_kb_all_clerks
				from @memory_clerks as mc_ta
		) as ta
		group by mc.snapshot_time, mc.snapshot_type_id, mc.sql_instance
			, case when mc.total_kb / convert(decimal, ta.total_kb_all_clerks) > 0.05 then mc.[type] else N'OTHER' end
	) t
	inner join [dbo].[sqlwatch_meta_dm_os_memory_clerk] mm
		on mm.clerk_name = t.[type] collate database_default
		and mm.sql_instance = t.sql_instance collate database_default
	option (keep plan);
end;