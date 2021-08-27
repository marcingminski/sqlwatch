CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_table] (
	@xdoc int,
	@sql_instance varchar(32)
)
as
begin
	set nocount on;

	/* when collecting tables we only consider name as a primary key. 
	   when table is dropped and recreated with the same name, we are treating it as the same table.
	   this behaviour is different to how we handle database. Quite often there are ETL processes that drop
	   and re-create tabe every nigth for example */

	--https://github.com/marcingminski/sqlwatch/issues/176

	select distinct
		[database_name] 
		,table_name 
		,[TABLE_TYPE] = 'BASE TABLE'
		,sql_instance = @sql_instance
		,database_create_date 
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/table_space_usage/row',1)
	--from openxml (@xdoc, '/MetaDataSnapshot/sys_tables/row',1)
		with (
			[database_name] nvarchar(128) 
			,table_name nvarchar(512)
			,database_create_date datetime2(3) 
		)	
	--from @data.nodes('/MetaDataSnapshot/sys_tables/row') t(x);
	option (maxdop 1, keep plan);

	merge [dbo].[sqlwatch_meta_table] as target
	using (
		select distinct
			  [t].table_name
			, [t].[TABLE_TYPE]
			, mdb.sqlwatch_database_id
			, mtb.sqlwatch_table_id
			, t.sql_instance
		from #t t
	
		inner join [dbo].[sqlwatch_meta_database] mdb
			on mdb.sql_instance = t.[sql_instance]
			and mdb.[database_name] = t.[database_name] collate database_default
			and mdb.[database_create_date] = t.[database_create_date]
	
		left join [dbo].[sqlwatch_meta_table] mtb
			on mtb.sql_instance = t.sql_instance
			and mtb.sqlwatch_database_id = mdb.sqlwatch_database_id
			and mtb.[table_name] = t.table_name collate database_default

		where t.sql_instance = @sql_instance
	
		) as source
	 on		target.sql_instance = source.[sql_instance] collate database_default
	 and	target.[table_name] = source.table_name collate database_default
	 and	target.[table_type] = source.[TABLE_TYPE] collate database_default
	 and	target.[sqlwatch_database_id] = source.[sqlwatch_database_id]

 		
	/* we dont need is record deleted field as its not always possible to tell.
	   we're using date last seen to handle this status */
	--when not matched by source and target.sql_instance = @@SERVERNAME then
	--	update set [is_record_deleted] = 1

	 when matched then
		update set [date_last_seen] = GETUTCDATE()

	/* a new database and/or table could have been added since last collection.
		in which case we have not got id yet, it will be picked up with the next cycle */
	 when not matched by target and source.[sqlwatch_database_id] is not null then
		insert ([sql_instance],[sqlwatch_database_id],[table_name],[table_type],[date_first_seen],[date_last_seen])
		values (source.sql_instance,source.[sqlwatch_database_id],source.[table_name],source.[table_type],GETUTCDATE(),GETUTCDATE());
end;