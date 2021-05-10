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
			@date_now datetime2(0) = getutcdate(),
			@sqlwatch_plan_id_output dbo.utype_plan_id;

	with cte_plans as (
		select 
			  RN_HANDLE = ROW_NUMBER() over (partition by ph.plan_handle, qs.query_plan_hash order by (select null))
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
			, [database_name] = db_name(qp.dbid)
			, [procedure_name] = isnull(object_schema_name(qp.objectid, qp.dbid) + '.' + object_name (qp.objectid, qp.[dbid]),'Ad-Hoc Query 3FBE6AA6')
		from @plan_handle ph

		inner join sys.dm_exec_query_stats qs 
			on ph.[plan_handle] = qs.[plan_handle]
			and ph.[statement_start_offset] = qs.[statement_start_offset]
			and ph.[statement_end_offset] = qs.[statement_end_offset]
			-- The idea is to also match on the sql_handle if present but I am not sure that we need to do this.
			and qs.[sql_handle] = case when ph.[sql_handle] is not null then ph.[sql_handle] else qs.[sql_handle] end

		cross apply sys.dm_exec_text_query_plan(ph.[plan_handle], ph.[statement_start_offset], ph.[statement_end_offset]) qp
	
		cross apply sys.dm_exec_sql_text(qs.sql_handle) t

		where qp.[encrypted] = 0
		and t.[encrypted] = 0
		and @get_plans = 1
		and ph.plan_handle <> 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
		and ph.statement_start_offset is not null
		and ph.statement_end_offset is not null
	)

	select 
		  p.RN_HANDLE
		, RN_HASH = ROW_NUMBER() over (partition by p.sql_instance, query_plan_hash order by (select null))
		, p.[plan_handle]
		, p.[sql_handle]
		, p.query_hash
		, p.query_plan_hash 
		, p.statement_start_offset
		, p.statement_end_offset
		, p.[statement] 
		, p.query_plan
		, p.sql_instance 
		, mp.sqlwatch_procedure_id
		, mdb.sqlwatch_database_id
	into #plans
	from cte_plans p

	inner join [dbo].[sqlwatch_meta_database] mdb
		on mdb.[database_name] = p.[database_name] collate database_default
		and mdb.is_current = 1
		and mdb.sql_instance = @sql_instance

	inner join [dbo].[sqlwatch_meta_procedure] mp
		on mp.sql_instance = @sql_instance
		and mp.[procedure_name] = p.[procedure_name] collate database_default
		and mp.sqlwatch_database_id = mdb.sqlwatch_database_id;

	create unique clustered index idx_tmp_plans on #plans ([plan_handle], [sql_handle], [query_hash]
		, [query_plan_hash], [sql_instance], sqlwatch_procedure_id, sqlwatch_database_id, RN_HANDLE, RN_HASH
		, statement_start_offset, statement_end_offset);

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
		select 
			  [sql_instance]
			, [query_plan_hash]
			, [statement]
			, [query_plan]
			--, [statement_start_offset]
			--, [statement_end_offset]
		from #plans 
		where RN_HASH = 1
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
			--, [statement_start_offset]
			--, [statement_end_offset]
			)
		values (
			  source.[sql_instance]
			, source.[query_plan_hash]
			, source.[statement]
			, source.query_plan 
			, @date_now
			, @date_now
			--, source.[statement_start_offset]
			--, source.[statement_end_offset]
			)
		;