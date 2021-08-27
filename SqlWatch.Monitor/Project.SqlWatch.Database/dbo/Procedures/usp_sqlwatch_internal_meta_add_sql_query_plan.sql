CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_sql_query_plan]
	@sqlwatch_sql_query_plan [dbo].[utype_sqlwatch_sql_query_plan] readonly,
	@sql_instance varchar(32)
as
begin
	merge [dbo].[sqlwatch_meta_sql_query_plan] as target
	using (
		select distinct
			query_hash,
			query_plan_hash,
			db.sqlwatch_database_id,
			p.sqlwatch_procedure_id,
			pt.query_plan,
			sql_instance = @sql_instance
		from @sqlwatch_sql_query_plan h

		inner join dbo.sqlwatch_meta_database db
			on db.sql_instance = @sql_instance
			and db.database_name = h.database_name
			and db.database_create_date = case when h.database_create_date is null then db.database_create_date else h.database_create_date end
			and db.is_current = 1
		
		inner join dbo.sqlwatch_meta_procedure p
			on p.sql_instance = @sql_instance
			and p.sqlwatch_database_id = db.sqlwatch_database_id
			and p.procedure_name = h.procedure_name

		outer apply (
			select top 1 query_plan
			from @sqlwatch_sql_query_plan dt
			where dt.query_hash = h.query_hash
			and dt.query_plan_hash = h.query_plan_hash
			and dt.database_name = h.database_name
			and dt.database_create_date = h.database_create_date
			and dt.procedure_name = h.procedure_name
			) pt

		where pt.query_plan is not null

		) as source

	on source.query_hash = target.query_hash
	and source.query_plan_hash = target.query_plan_hash
	and source.sqlwatch_database_id = target.sqlwatch_database_id
	and source.sqlwatch_procedure_id = target.sqlwatch_procedure_id
	and source.sql_instance = target.sql_instance

	when matched then
		update set date_last_seen = getutcdate(),
			times_seen = isnull(times_seen,0) + 1

	when not matched then
		insert (
			[sql_instance] ,
			[query_hash] ,
			[query_plan_hash] ,
			[query_plan_sample] ,
			[date_first_seen] ,
			[date_last_seen] ,
			last_usage_stats_snapshot_time ,
			[sqlwatch_procedure_id] ,
			[sqlwatch_database_id],
			times_seen
			)

		values (
			source.sql_instance,
			source.query_hash,
			source.query_plan_hash,
			source.query_plan,
			getutcdate(),
			getutcdate(),
			null,
			source.sqlwatch_procedure_id,
			source.sqlwatch_database_id,
			1
		)
		;
end;