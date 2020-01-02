CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_master_file]
as


merge [dbo].[sqlwatch_meta_master_file] as target
using (
	select mdb.sqlwatch_database_id, 
	mf.[file_id], mf.[type], mf.[physical_name], [sql_instance]=@@SERVERNAME, [file_name] = mf.[name] 
	,cast (case
	when left (ltrim (mf.physical_name), 2) = '\\' 
			then left (ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), 3) + 1) - 1)
		when charindex ('\', ltrim(mf.physical_name), 3) > 0 
			then upper (left (ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), 3) - 1))
		else mf.physical_name
	end as varchar(255)) as logical_disk
	from sys.master_files mf
	inner join dbo.vw_sqlwatch_sys_databases db
		on db.database_id = mf.database_id
	inner join [dbo].[sqlwatch_meta_database] mdb
		on mdb.sql_instance = @@SERVERNAME
		and mdb.database_name = convert(nvarchar(128),db.name) collate database_default
		and mdb.database_create_date = db.create_date
	)as source
 on (
		source.file_id = target.file_id
	and source.[file_name] = target.[file_name] collate database_default
	and source.physical_name = target.file_physical_name collate database_default
	and	source.sql_instance = target.sql_instance
 )

 when not matched by source and target.sql_instance = @@SERVERNAME then
	update set [is_record_deleted] = 1

when matched then
	update
		set [date_last_seen] = getutcdate(),
			[is_record_deleted] = 0

when not matched by target then
	insert ( [sqlwatch_database_id], [file_id], [file_type], [file_physical_name], [sql_instance], [file_name], [logical_disk] )
	values ( source.[sqlwatch_database_id], source.[file_id], source.[type], source.[physical_name], source.[sql_instance], source.[file_name], source.[logical_disk] );

--when not matched by source and target.sql_instance = @@SERVERNAME then 
--	update set deleted_when = GETUTCDATE();