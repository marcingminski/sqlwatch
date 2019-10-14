CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_index_missing]
as

merge [dbo].[sqlwatch_meta_index_missing] as target
using (
	select
		[sql_instance] = @@SERVERNAME,
		db.[sqlwatch_database_id] ,
		mt.[sqlwatch_table_id] ,
		[equality_columns] ,
		[inequality_columns] ,
		[included_columns] ,
		[statement] ,
		id.[index_handle] ,
		[date_added] = GETUTCDATE()
	from sys.dm_db_missing_index_details id

	inner join sys.databases sdb
		on id.database_id = sdb.database_id
	inner join sys.tables t
		on t.object_id = id.object_id
	inner join sys.schemas s
		on t.schema_id = s.schema_id

	inner join [dbo].[sqlwatch_meta_database] db
		on db.[database_name] = db_name(sdb.[database_id])
		and db.[database_create_date] = sdb.[create_date]
		and db.sql_instance = @@SERVERNAME

	inner join [dbo].[sqlwatch_meta_table] mt
		on mt.sql_instance = db.sql_instance
		and mt.sqlwatch_database_id = db.sqlwatch_database_id
		and mt.table_name = s.name + '.' + t.name
		) as source
	on	target.sql_instance = source.sql_instance
	and target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.sqlwatch_table_id = source.sqlwatch_table_id
	and target.index_handle = source.index_handle
	and isnull(target.[equality_columns],'') = isnull(source.[equality_columns],'') collate database_default
	and isnull(target.[inequality_columns],'') = isnull(source.[inequality_columns],'') collate database_default
	and isnull(target.[included_columns],'') = isnull(source.[included_columns],'') collate database_default
	and isnull(target.[statement],'') = isnull(source.[statement],'') collate database_default

when matched then
	update set [date_deleted] = null

when not matched by target then
	insert ([sql_instance], [sqlwatch_database_id], [sqlwatch_table_id],		[equality_columns] ,
		[inequality_columns] ,[included_columns] ,[statement] , [index_handle] , [date_added])
	values (source.[sql_instance], source.[sqlwatch_database_id], source.[sqlwatch_table_id], source.[equality_columns] ,
		source.[inequality_columns] ,source.[included_columns] ,source.[statement] , source.[index_handle] , source.[date_added])

when not matched by source then
	update set [date_deleted] = getutcdate();