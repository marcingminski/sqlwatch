CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_index_missing]
as

declare @database_name sysname,
		@database_create_date datetime,
		@sql nvarchar(max)

create table #t (
		[database_name] nvarchar(128), 
		[create_date] datetime,
		[table_name] nvarchar(256),
		[equality_columns]  nvarchar(max),
		[inequality_columns] nvarchar(max),
		[included_columns] nvarchar(max),
		[statement] nvarchar(max),
		[index_handle] int
)

create clustered index idx_tmp_t on #t ([database_name], [create_date], [table_name], [index_handle])

declare cur_database cursor for
select [name] , [create_date]
from [dbo].[vw_sqlwatch_sys_databases]

open cur_database

fetch next from cur_database into @database_name , @database_create_date

while @@FETCH_STATUS = 0
	begin
		set @sql = 'use [' + @database_name + ']
			select
				[database_name] = ''' + @database_name + ''',
				[create_date] = ''' + convert(varchar(23),@database_create_date,121) + ''',
				[table_name] = s.name + ''.'' + t.name,
				[equality_columns] ,
				[inequality_columns] ,
				[included_columns] ,
				[statement] ,
				id.[index_handle]
			from sys.dm_db_missing_index_details id

			inner join [' + @database_name + '].sys.tables t
				on t.object_id = id.object_id
			inner join [' + @database_name + '].sys.schemas s
				on t.schema_id = s.schema_id'
				
		insert into #t
		exec sp_executesql @sql

		fetch next from cur_database into @database_name, @database_create_date
	end



merge [dbo].[sqlwatch_meta_index_missing] as target
using (
select
		[sql_instance] = @@SERVERNAME,
		db.[sqlwatch_database_id] ,
		mt.[sqlwatch_table_id] ,
		idx.[equality_columns] ,
		idx.[inequality_columns] ,
		idx.[included_columns] ,
		idx.[statement] ,
		idx.[index_handle] ,
		[date_added] = getdate()
	from #t idx

	inner join [dbo].[sqlwatch_meta_database] db
		on db.[database_name] = idx.[database_name] collate database_default
		and db.[database_create_date] = idx.[create_date]
		and db.sql_instance = @@SERVERNAME

	inner join [dbo].[sqlwatch_meta_table] mt
		on mt.sql_instance = db.sql_instance
		and mt.sqlwatch_database_id = db.sqlwatch_database_id
		and mt.table_name = idx.table_name collate database_default

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
		source.[inequality_columns] ,source.[included_columns] ,source.[statement] , source.[index_handle] , source.[date_added]);

--when not matched by source and target.sql_instance = @@SERVERNAME then
--	update set [date_deleted] = getutcdate();