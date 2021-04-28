CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_query_plans]
	@plan_handle utype_plan_handle readonly,
	@sql_instance varchar(32)
AS
	set nocount on;
	set xact_abort on;

	declare @get_plan_xml bit = dbo.ufn_sqlwatch_get_config_value(22,null),
			@date_now datetime2(0) = getutcdate();

	declare @sqlwatch_plan_id_output dbo.utype_plan_id;

	select 
		RN = ROW_NUMBER() over (partition by sql_instance, query_hash, query_plan_hash order by (select null))
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
		--query plans are plain text in sys.dm_exec_text_query_plan to avoid nesting problems.
		--since this procedure will run often, and relatively right after the event happen we would expect to always find a plan
		--low memory could cause sql server to evict plans too quickly.
		, query_plan = isnull(qp.query_plan,'Not found - Evicted?') 
		, sql_instance = @sql_instance
		, object_name = object_schema_name(qp.objectid, qp.dbid) + '.' + object_name (qp.objectid, qp.dbid)
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
		on mdb.database_name = db_name(qp.dbid) collate database_default
		and mdb.is_current = 1
		and mdb.sql_instance = @sql_instance

	where qp.[encrypted] = 0
	and t.[encrypted] = 0;


	--create unique clustered index idx_tmp_plans on #plans ([plan_handle], [sql_handle], [query_hash], [query_plan_hash], [sql_instance])
	merge [dbo].[sqlwatch_meta_query_plan_handle] as target
	using (
		select distinct 
			sql_instance ,
			[plan_handle],
			[sql_handle] ,
			[query_hash] ,
			[query_plan_hash] ,
			[statement_start_offset] ,
			[statement_end_offset]
		from #plans
	) as source
		on source.sql_instance = target.sql_instance
		and source.[plan_handle] = target.[plan_handle]
		and source.[statement_start_offset] = target.[statement_start_offset]
		and source.[statement_end_offset] = target.[statement_end_offset]

	when not matched then
		insert (sql_instance ,[plan_handle],[sql_handle] ,[query_hash] ,[query_plan_hash] ,[statement_start_offset] ,[statement_end_offset], date_updated)
		values (	source.sql_instance ,source.[plan_handle],source.[sql_handle] ,source.[query_hash]
				,	source.[query_plan_hash] ,source.[statement_start_offset] ,source.[statement_end_offset], getutcdate())
		;


	merge dbo.sqlwatch_meta_query_plan as target
	using (
		select distinct 
			  [sql_instance]
			, [query_hash]
			, [query_plan_hash]
			, [statement]
			, [query_plan]
			, RN
		from #plans 
		where RN = 1
	)as source
	on target.[query_hash] = source.[query_hash]
	and target.[query_plan_hash] = source.[query_plan_hash]
	and target.[sql_instance] = source.[sql_instance]

	when matched then 
		update set 
			date_last_seen = @date_now

	when not matched then
		insert ( 
			  [sql_instance]
			, [query_hash]
			, [query_plan_hash]
			, [statement]
			, [query_plan]
			, [date_first_seen]
			, [date_last_seen]
			)
		values (
			  source.[sql_instance]
			, source.[query_hash]
			, source.[query_plan_hash]
			, source.[statement]
			, case when @get_plan_xml = 1 then source.query_plan else null end
			, @date_now
			, @date_now
			)

	output 
		 inserted.[sqlwatch_query_plan_id] 
		,inserted.[query_hash] 
		,inserted.[query_plan_hash] 
		,$action
	into @sqlwatch_plan_id_output

	;

	/* each query plan must have a database (impossible to run a query without a database) */
	merge [dbo].[sqlwatch_meta_query_plan_database] as target
	using (
		select distinct
			 sql_instance = p.sql_instance
			,pid.[sqlwatch_query_plan_id] 
			,p.sqlwatch_database_id
		from @sqlwatch_plan_id_output pid

		inner join #plans p
			on p.[query_hash] = pid.[query_hash]
			and p.[query_plan_hash] = pid.[query_plan_hash]

		where [action] = 'INSERT'

	) as source

	on target.sql_instance = source.sql_instance
	and target.[sqlwatch_query_plan_id] = source.[sqlwatch_query_plan_id]
	and target.sqlwatch_database_id = source.sqlwatch_database_id

	when not matched then
		insert (sql_instance, sqlwatch_database_id, [sqlwatch_query_plan_id], [date_updated])
		values (source.sql_instance, source.sqlwatch_database_id, source.[sqlwatch_query_plan_id], @date_now)
	;

	/* in addition, some plans may have a procedure (some may come from ad-hoc queries and will not have a procedure */
	merge [dbo].[sqlwatch_meta_procedure_query_plan] as target
	using (
		select distinct
			 sql_instance = p.sql_instance
			,pid.[sqlwatch_query_plan_id] 
			,mp.sqlwatch_procedure_id
			,p.sqlwatch_database_id
		from @sqlwatch_plan_id_output pid

		inner join #plans p
			on p.[query_hash] = pid.[query_hash]
			and p.[query_plan_hash] = pid.[query_plan_hash]

		inner join [dbo].[sqlwatch_meta_procedure] mp
			on mp.sql_instance = p.sql_instance
			and mp.[procedure_name] = p.[object_name]
			and mp.sqlwatch_database_id = p.sqlwatch_database_id

		where [action] = 'INSERT'

	) as source

	on target.sql_instance = source.sql_instance
	and target.[sqlwatch_query_plan_id] = source.[sqlwatch_query_plan_id]
	and target.sqlwatch_procedure_id = source.sqlwatch_procedure_id
	and target.sqlwatch_database_id = source.sqlwatch_database_id

	when not matched then
		insert (sql_instance, [sqlwatch_procedure_id], [sqlwatch_database_id], [sqlwatch_query_plan_id], [date_updated])
		values (source.sql_instance, source.[sqlwatch_procedure_id], source.[sqlwatch_database_id], source.[sqlwatch_query_plan_id], @date_now)
	;

	select * from @sqlwatch_plan_id_output