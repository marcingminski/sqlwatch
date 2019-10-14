CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_index]
as

create table ##DB61B2CD92324E4B89019FFA7BEF1010 (
	index_name nvarchar(128), 
	index_id int,
	index_type_desc nvarchar(128),
	[table_name] nvarchar(128),
	[database_name] nvarchar(128),
	sqlwatch_database_id smallint null,
	sqlwatch_table_id int null
)

create unique clustered index icx_tmp_DB61B2CD92324E4B89019FFA7BEF1010 on ##DB61B2CD92324E4B89019FFA7BEF1010 ([table_name],[database_name],index_id)

exec sp_MSforeachdb'
use [?]
insert into ##DB61B2CD92324E4B89019FFA7BEF1010 (index_name, index_id, index_type_desc, [table_name], [database_name])
select ix.name, ix.index_id, ix.type_desc, s.name + ''.'' + t.name, ''?''
from sys.indexes ix
inner join sys.tables t 
	on t.[object_id] = ix.[object_id]
inner join sys.schemas s 
	on s.[schema_id] = t.[schema_id]
where ix.name is not null
and ''?'' <> ''tempdb''
and objectproperty( ix.object_id, ''IsMSShipped'' ) = 0 
'
update t
	set sqlwatch_database_id = md.sqlwatch_database_id, 
	sqlwatch_table_id = mt.sqlwatch_table_id
from ##DB61B2CD92324E4B89019FFA7BEF1010 t

inner join [dbo].[sqlwatch_meta_database] md
	on md.[database_name] = t.[database_name] collate database_default
	and md.sql_instance = @@SERVERNAME

inner join [dbo].[sqlwatch_meta_table] mt
	on mt.table_name = t.table_name collate database_default
	and mt.sqlwatch_database_id = md.sqlwatch_database_id
	and mt.sql_instance = md.sql_instance

inner join sys.databases dbs
	on dbs.name = md.database_name collate database_default
	and dbs.create_date = md.database_create_date


merge [dbo].[sqlwatch_meta_index] as target
	using ##DB61B2CD92324E4B89019FFA7BEF1010 as source
on target.sqlwatch_database_id = source.sqlwatch_database_id
and target.sqlwatch_table_id = source.sqlwatch_table_id
and target.sql_instance = @@SERVERNAME
and target.index_name = source.index_name collate database_default

when matched then
	update set date_deleted = null,
		index_id = case when source.index_id <> target.index_id then source.index_id else target.index_id end,
		index_type_desc = case when source.index_type_desc <> target.index_type_desc collate database_default then source.index_type_desc else target.index_type_desc end collate database_default,
		date_updated = case when source.index_id <> target.index_id or source.index_type_desc <> target.index_type_desc collate database_default then GETUTCDATE() else date_updated end

when not matched by source then
	update set date_deleted = GETUTCDATE()

	                           --a new index could have been added since we collected tables.
when not matched by target and source.sqlwatch_table_id is not null then
	insert ([sql_instance],[sqlwatch_database_id],[sqlwatch_table_id],[index_id],[index_type_desc],[index_name])
	values (@@SERVERNAME,source.[sqlwatch_database_id],source.[sqlwatch_table_id],source.[index_id],source.[index_type_desc],source.[index_name]);
