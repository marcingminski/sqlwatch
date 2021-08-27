CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_index] (
	@xdoc int,
	@sql_instance varchar(32)
)
as
begin
	set nocount on;

	merge [dbo].[sqlwatch_meta_index] as target
		using (
			select distinct
				t.[index_name]
				, t.[index_id]
				, [index_type_desc] = [type_desc]
				, t.[table_name]
				, t.[database_name]
				, t.[database_create_date]
				, sql_instance = @sql_instance
				, sqlwatch_database_id = md.sqlwatch_database_id
				, sqlwatch_table_id = mt.sqlwatch_table_id
			from openxml (@xdoc, '/CollectionSnapshot/index_usage_stats/row',1) 
				with (
					[index_name] nvarchar(128)
					, [index_id] int
					, [type_desc] nvarchar(60)
					, table_name nvarchar(512)
					, [database_name] nvarchar(128)
					, database_create_date datetime2(3)
				) t

			inner join [dbo].[sqlwatch_meta_database] md
				on md.[database_name] = t.[database_name] collate database_default
				and md.database_create_date = t.database_create_date
				and md.sql_instance = @sql_instance

			inner join [dbo].[sqlwatch_meta_table] mt
				on mt.table_name = t.table_name collate database_default
				and mt.sqlwatch_database_id = md.sqlwatch_database_id
				and mt.sql_instance = @sql_instance

		) as source
	on target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.sqlwatch_table_id = source.sqlwatch_table_id
	and target.sql_instance = source.sql_instance
	and target.index_name = source.index_name collate database_default

	when not matched by source and target.sql_instance = @sql_instance then
		update set [is_record_deleted] = 1

	when matched then
		update set [date_last_seen] = getutcdate(),
			[is_record_deleted] = 0,
			index_id = case when source.index_id is null or source.index_id <> target.index_id then source.index_id else target.index_id end,
			index_type_desc = case when source.index_type_desc <> target.index_type_desc collate database_default then source.index_type_desc else target.index_type_desc end collate database_default

	when not matched by target and source.sqlwatch_table_id is not null then
		insert ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id],[index_id],[index_type_desc],[index_name],[date_first_seen],date_last_seen)
		values (source.sql_instance,source.[sqlwatch_database_id],source.[sqlwatch_table_id],source.[index_id],source.[index_type_desc],source.[index_name],getutcdate(),getutcdate());
end;