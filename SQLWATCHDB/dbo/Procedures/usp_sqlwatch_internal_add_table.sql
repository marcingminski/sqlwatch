CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_table]
as

create table ##98308FFC2C634BF98B347EECB98E3490 (
	[TABLE_CATALOG] [nvarchar](128) NOT NULL,
	[TABLE_SCHEMA] [sysname] NOT NULL,
	[TABLE_NAME] [sysname] NOT NULL,
	[TABLE_TYPE] [varchar](10) NULL,
	[sqlwatch_database_id] smallint,
	constraint PK_TMP_98308FFC2C634BF98B347EECB98E3490 primary key clustered (
		[TABLE_CATALOG], [TABLE_SCHEMA], [TABLE_NAME]
		)
)


exec sp_MSforeachdb '
USE [?]
insert into ##98308FFC2C634BF98B347EECB98E3490 ([TABLE_CATALOG],[TABLE_SCHEMA],[TABLE_NAME],[TABLE_TYPE])
SELECT [TABLE_CATALOG],[TABLE_SCHEMA],[TABLE_NAME],[TABLE_TYPE] 
from INFORMATION_SCHEMA.TABLES
WHERE''?'' <> ''tempdb'''

update t
	set sqlwatch_database_id = db.sqlwatch_database_id
from ##98308FFC2C634BF98B347EECB98E3490 t

inner join [dbo].[sqlwatch_meta_database] db
	on db.[database_name] = TABLE_CATALOG collate database_default

inner join sys.databases dbs
	on dbs.name = db.database_name collate database_default
	and dbs.create_date = db.database_create_date

/* when collecting tables we only consider name as a primary key. 
   when table is dropped and recreated with the same name, we are treating it as the same table.
   this behaviour is different to how we handle database. Quite often there are ETL processes that drop
   and re-create tabe every nigth for example */
merge [dbo].[sqlwatch_meta_table] as target
using ##98308FFC2C634BF98B347EECB98E3490 as source
 on		target.sql_instance = @@SERVERNAME
 and	target.[table_name] = source.[TABLE_SCHEMA] + '.' + source.[TABLE_NAME] collate database_default
 and	target.[table_type] = source.[table_type] collate database_default
 and	target.[sqlwatch_database_id] = source.[sqlwatch_database_id]

 when not matched by source then
	update set [date_deleted] = GETUTCDATE()

								/* a new database could have been added since last db collection.
								   in which case we have not got id yet, it will be picked up with the next cycle */
 when not matched by target and source.[sqlwatch_database_id] is not null then
	insert ([sql_instance],[sqlwatch_database_id],[table_name],[table_type],[date_added])
	values (@@SERVERNAME,source.[sqlwatch_database_id],source.[TABLE_SCHEMA] + '.' + source.[TABLE_NAME],source.[table_type],GETUTCDATE())

 when matched and [date_deleted]  is not null then
	update set [date_deleted] = null;