CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_query_plans]
	@plan_handle utype_plan_handle readonly,
	@sql_instance varchar(32)
AS
	set nocount on;
	set xact_abort on;

	/*  
		The idea is to store query plans and statements based on the query_hash and query_plan_hash.
		This will greatly reduce the number of stored plans but would mean that the query_plan may differ slightly to the one executed.
		https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql
		
		query_hash		Binary hash value calculated on the query and used to identify queries with similar logic. 

		query_plan_hash	Binary hash value calculated on the query execution plan and used to identify similar query execution plans. 
						Will always be 0x000 when a natively compiled stored procedure queries a memory-optimized table.

		so for example, two queries:
			"select * from table where date = 'date1'"
			"select * from table where date = 'date2'"
		will likely have different plan_handle and sql_handle but the same hash and we will only store the first one we encounter for the combination of 
		query hash and plan hash

		In addition, queries that have null or 0x000 hash will be stored in the [dbo].[sqlwatch_meta_query_plan_handle] 
		As there should be less of these than those with hash, we are going to hopefully save alot of storage and still provide useful data.
		this will be configurable in via config_table where users will be able to switch on/off where to save plans based on their workloads
		or disable if the tables get too big etc.
	*/

	declare @get_plans bit = dbo.ufn_sqlwatch_get_config_value(22,null),
			@date_now datetime2(0) = getutcdate();

	declare @sqlwatch_plan_id_output dbo.utype_plan_id;

	select 
		  RN = ROW_NUMBER() over (partition by ph.plan_handle, qs.query_plan_hash order by (select null))
		, ph.[plan_handle]
		, qs.[sql_handle]
		, query_hash = qs.query_hash
		, query_plan_hash = qs.query_plan_hash
		, ph.statement_start_offset
		, ph.statement_end_offset
		, [statement] = substring(t.text, (ph.statement_start_offset/2)+1,((case qs.statement_end_offset
						when -1 then datalength(t.text)
						else qs.statement_end_offset
						end - qs.statement_start_offset)/2) + 1)
		, qp.query_plan
		, sql_instance = @sql_instance
		, mp.sqlwatch_procedure_id
		, mdb.sqlwatch_database_id
	into #plans
	from @plan_handle ph
	inner join sys.dm_exec_query_stats qs 
		on ph.[plan_handle] = qs.[plan_handle]
		and ph.[statement_start_offset] = qs.[statement_start_offset]
		and ph.[statement_end_offset] = qs.[statement_end_offset]
		-- The idea is to also match on the sql_handle if present but I am not sure that we need to do this.
		and qs.[sql_handle] = case when ph.[sql_handle] is not null then ph.[sql_handle] else qs.[sql_handle] end

	cross apply sys.dm_exec_text_query_plan(ph.[plan_handle], ph.[statement_start_offset], ph.[statement_end_offset]) qp
	
	cross apply sys.dm_exec_sql_text(qs.sql_handle) t

	inner join [dbo].[sqlwatch_meta_database] mdb
		on mdb.[database_name] = db_name(qp.dbid) collate database_default
		and mdb.is_current = 1
		and mdb.sql_instance = @sql_instance

	inner join [dbo].[sqlwatch_meta_procedure] mp
		on mp.sql_instance = @sql_instance
		and mp.[procedure_name] = isnull(object_schema_name(qp.objectid, qp.dbid) + '.' + object_name (qp.objectid, qp.[dbid]),'Ad-Hoc Query 3FBE6AA6')
		and mp.sqlwatch_database_id = mdb.sqlwatch_database_id

	where qp.[encrypted] = 0
	and t.[encrypted] = 0
	and @get_plans = 1
	and ph.plan_handle <> 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
	and ph.statement_start_offset is not null
	and ph.statement_end_offset is not null

	create unique clustered index idx_tmp_plans on #plans ([plan_handle], [sql_handle], [query_hash], [query_plan_hash], [sql_instance])
	merge [dbo].[sqlwatch_meta_query_plan] as target
	using (
		select distinct 
			sql_instance ,
			[plan_handle],
			[sql_handle] ,
			[query_hash] ,
			[query_plan_hash] ,
			[statement_start_offset] ,
			[statement_end_offset],
			sqlwatch_procedure_id,
			sqlwatch_database_id,
			[query_plan] = case when ([query_plan_hash] is null or [query_plan_hash] = 0x00) then query_plan else null end,
			[statement] = case when [query_plan_hash] is null or [query_plan_hash] = 0x00 then [statement] else null end
		from #plans
	) as source
		on source.sql_instance = target.sql_instance
		and source.[plan_handle] = target.[plan_handle]
		and source.[statement_start_offset] = target.[statement_start_offset]
		and source.[statement_end_offset] = target.[statement_end_offset]
		and source.sqlwatch_procedure_id = target.sqlwatch_procedure_id
		and source.sqlwatch_database_id = target.sqlwatch_database_id
	
	when matched then 
		update set date_last_seen = @date_now

	when not matched then
		insert (  [sql_instance] 
				, [plan_handle]
				, [sql_handle] 
				, [query_hash] 
				, [query_plan_hash] 
				, [statement_start_offset] 
				, [statement_end_offset]
				, [date_first_seen]
				, [date_last_seen]
				, sqlwatch_procedure_id
				, sqlwatch_database_id
				, [query_plan_for_plan_handle]
				, [statement_for_plan_handle]
				)
		values (  source.sql_instance 
				, source.[plan_handle]
				, source.[sql_handle]
				, source.[query_hash]
				, source.[query_plan_hash] 
				, source.[statement_start_offset]
				, source.[statement_end_offset]
				, @date_now
				, @date_now
				, source.sqlwatch_procedure_id
				, source.sqlwatch_database_id
				, source.[query_plan]
				, source.[statement]
				)
		;

	merge dbo.[sqlwatch_meta_query_plan_hash] as target
	using (
		select distinct 
			  [sql_instance]
			, [query_plan_hash]
			, [statement]
			, [query_plan]
			, [statement_start_offset]
			, [statement_end_offset]
			, RN
		from #plans 
		where RN = 1
		and [query_plan_hash] not in (0x000,0x00)

	)as source
	on target.[query_plan_hash] = source.[query_plan_hash]
	and target.[sql_instance] = source.[sql_instance]

	when matched then 
		update set 
			date_last_seen = @date_now

	when not matched then
		insert ( 
			  [sql_instance]
			, [query_plan_hash]
			, [statement_for_query_plan_hash]
			, [query_plan_for_query_plan_hash]
			, [date_first_seen]
			, [date_last_seen]
			, [statement_start_offset]
			, [statement_end_offset]
			)
		values (
			  source.[sql_instance]
			, source.[query_plan_hash]
			, source.[statement]
			, source.query_plan 
			, @date_now
			, @date_now
			, source.[statement_start_offset]
			, source.[statement_end_offset]
			)
		;

	--output 
	--	 inserted.[sqlwatch_query_plan_id] 
	--	,inserted.[query_hash] 
	--	,inserted.[query_plan_hash] 
	--	,$action
	--into @sqlwatch_plan_id_output

	--;

	/* each query plan must have a database (impossible to run a query without a database) */
	--merge [dbo].[sqlwatch_meta_query_plan_database] as target
	--using (
	--	select distinct
	--		 sql_instance = p.sql_instance
	--		,pid.[sqlwatch_query_plan_id]
	--		,p.sqlwatch_database_id
	--	from @sqlwatch_plan_id_output pid

	--	inner join #plans p
	--		on p.[query_hash] = pid.[query_hash]
	--		and p.[query_plan_hash] = pid.[query_plan_hash]

	--	where [action] = 'INSERT'

	--) as source

	--on target.sql_instance = source.sql_instance
	--and target.[sqlwatch_query_plan_id] = source.[sqlwatch_query_plan_id]
	--and target.sqlwatch_database_id = source.sqlwatch_database_id

	--when not matched then
	--	insert (sql_instance, sqlwatch_database_id, [sqlwatch_query_plan_id], [date_updated])
	--	values (source.sql_instance, source.sqlwatch_database_id, source.[sqlwatch_query_plan_id], @date_now)
	--;

	/* in addition, some plans may have a procedure (some may come from ad-hoc queries and will not have a procedure */
	--merge [dbo].[sqlwatch_meta_query_plan_procedure] as target
	--using (
	--	select distinct
	--		 sql_instance = p.sql_instance
	--		,pid.[sqlwatch_query_plan_id] 
	--		,mp.sqlwatch_procedure_id
	--		,p.sqlwatch_database_id
	--	from @sqlwatch_plan_id_output pid

	--	inner join #plans p
	--		on p.[query_hash] = pid.[query_hash]
	--		and p.[query_plan_hash] = pid.[query_plan_hash]

	--	inner join [dbo].[sqlwatch_meta_procedure] mp
	--		on mp.sql_instance = p.sql_instance
	--		and mp.[procedure_name] = p.[object_name]
	--		and mp.sqlwatch_database_id = p.sqlwatch_database_id

	--	where [action] = 'INSERT'

	--) as source

	--on target.sql_instance = source.sql_instance
	--and target.[sqlwatch_query_plan_id] = source.[sqlwatch_query_plan_id]
	--and target.sqlwatch_procedure_id = source.sqlwatch_procedure_id
	--and target.sqlwatch_database_id = source.sqlwatch_database_id

	--when not matched then
	--	insert (sql_instance, [sqlwatch_procedure_id], [sqlwatch_database_id], [sqlwatch_query_plan_id], [date_updated])
	--	values (source.sql_instance, source.[sqlwatch_procedure_id], source.[sqlwatch_database_id], source.[sqlwatch_query_plan_id], @date_now)
	--;

	--select * from @sqlwatch_plan_id_output