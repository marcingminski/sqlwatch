CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_sql_query]
	@sqlwatch_sql_query_plan [dbo].[utype_sqlwatch_sql_query_plan] readonly,
	@sql_instance varchar(32)
as
begin
	
	set nocount on;

	/*
	the purpose of query_hash is to identify the same base query regardles of its parameters
	therefore we can get mutliple different (although very similar) sql_statements per hash
	in this table, we will store the first available sql_statement for this particular hash

	for example, these two queries have the same hash:

	query_hash			sql_statement
	0x1DC129C1025BD20F	IF @BackupSoftware = 'LITESPEED' AND NOT EXISTS (SELECT * FROM [master].sys.objects WHERE [type] = 'X' AND [name] = 'xp_backup_database
	0x1DC129C1025BD20F	IF @BackupSoftware = 'DATA_DOMAIN_BOOST' AND NOT EXISTS (SELECT * FROM [master].sys.objects WHERE [type] = 'PC' AND [name] = 'emc_run_backup

	*/

	merge [dbo].[sqlwatch_meta_sql_query] as target
	using (
		select distinct 
			h.query_hash
			, db.sqlwatch_database_id
			, p.sqlwatch_procedure_id
			, sql_statement = st.sql_text
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
			select top 1 sql_text
			from @sqlwatch_sql_query_plan
			where query_hash = h.query_hash
			) st

		where h.query_hash is not null

		) as source
	on target.query_hash = source.query_hash
	and target.sql_instance = @sql_instance
	and target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.sqlwatch_procedure_id = source.sqlwatch_procedure_id

	when matched then update
		set date_last_seen = getutcdate(),
			times_seen = isnull(times_seen,0) + 1

	when not matched then
		insert (
			[sql_instance]
			,[query_hash]
			,[sql_statement_sample]
			,[date_first_seen]
			,[date_last_seen]
			,sqlwatch_database_id
			,sqlwatch_procedure_id
			,times_seen
			)
		values (
			@sql_instance
			,source.[query_hash]
			,source.[sql_statement]
			,getutcdate()
			,getutcdate()
			,source.sqlwatch_database_id
			,source.sqlwatch_procedure_id
			,1
		);

	exec [dbo].[usp_sqlwatch_internal_meta_add_sql_query_plan]
		@sqlwatch_sql_query_plan = @sqlwatch_sql_query_plan,
		@sql_instance = @sql_instance;
end;
