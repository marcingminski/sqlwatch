CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_table]
as

create table ##98308FFC2C634BF98B347EECB98E3490 (
	[TABLE_CATALOG] [nvarchar](128) NOT NULL,
	[TABLE_SCHEMA] [sysname] NOT NULL,
	[TABLE_NAME] [sysname] NOT NULL,
	[TABLE_TYPE] [varchar](10) NULL,
	constraint PK_TMP_98308FFC2C634BF98B347EECB98E3490 primary key clustered (
		[TABLE_CATALOG], [TABLE_SCHEMA], [TABLE_NAME]
		)
)


exec [dbo].[usp_sqlwatch_internal_foreachdb] @command = '
USE [?]
insert into ##98308FFC2C634BF98B347EECB98E3490 ([TABLE_CATALOG],[TABLE_SCHEMA],[TABLE_NAME],[TABLE_TYPE])
SELECT [TABLE_CATALOG],[TABLE_SCHEMA],[TABLE_NAME],[TABLE_TYPE] 
from INFORMATION_SCHEMA.TABLES
WHERE''?'' <> ''tempdb''', @databases = '-tempdb', @calling_proc_id = @@PROCID

/* when collecting tables we only consider name as a primary key. 
   when table is dropped and recreated with the same name, we are treating it as the same table.
   this behaviour is different to how we handle database. Quite often there are ETL processes that drop
   and re-create tabe every nigth for example */
merge [dbo].[sqlwatch_meta_table] as target
using (
	select [t].[TABLE_CATALOG], [t].[TABLE_SCHEMA], [t].[TABLE_NAME], [t].[TABLE_TYPE], mdb.sqlwatch_database_id, mtb.sqlwatch_table_id
	from ##98308FFC2C634BF98B347EECB98E3490 t
	inner join [dbo].[vw_sqlwatch_sys_databases] dbs
		on dbs.name = t.TABLE_CATALOG 
	inner join [dbo].[sqlwatch_meta_database] mdb
		on mdb.database_name = dbs.name collate database_default
		and mdb.database_create_date = dbs.create_date
		and mdb.sql_instance = @@SERVERNAME
	left join [dbo].[sqlwatch_meta_table] mtb
		on mtb.sql_instance = mdb.sql_instance
		and mtb.sqlwatch_database_id = mdb.sqlwatch_database_id
		and mtb.table_name = t.TABLE_SCHEMA + '.' + t.TABLE_NAME collate database_default
	) as source
 on		target.sql_instance = @@SERVERNAME
 and	target.[table_name] = source.[TABLE_SCHEMA] + '.' + source.[TABLE_NAME] collate database_default
 and	target.[table_type] = source.[table_type] collate database_default
 and	target.[sqlwatch_database_id] = source.[sqlwatch_database_id]

 		
when not matched by source and target.sql_instance = @@SERVERNAME then
	update set [is_record_deleted] = 1

 when matched and target.sql_instance = @@SERVERNAME 
	then update set [date_last_seen] = GETUTCDATE(),
		[is_record_deleted] = 0

								/* a new database could have been added since last db collection.
								   in which case we have not got id yet, it will be picked up with the next cycle */
 when not matched by target and source.[sqlwatch_database_id] is not null then
	insert ([sql_instance],[sqlwatch_database_id],[table_name],[table_type],[date_created])
	values (@@SERVERNAME,source.[sqlwatch_database_id],source.[TABLE_SCHEMA] + '.' + source.[TABLE_NAME],source.[table_type],GETUTCDATE());

 --when matched and [date_deleted] is not null and target.sql_instance = @@SERVERNAME then
	--update set [date_deleted] = null;