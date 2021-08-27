CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_master_file]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	merge [dbo].[sqlwatch_meta_master_file] as target
	using (
		select 
			  mdb.sqlwatch_database_id
			, mf.[file_id]
			, mf.[type]
			, mf.[physical_name]
			, [sql_instance] = @sql_instance
			, [file_name] = mf.[name]
			,logical_disk = convert(varchar(255),
				case 
					when left (ltrim (mf.physical_name), 2) = '\\' 
						then left (ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), 3) + 1) - 1)
					when charindex ('\', ltrim(mf.physical_name), 3) > 0 
						then upper (left (ltrim (mf.physical_name), charindex ('\', ltrim (mf.physical_name), 3) - 1))
					else mf.physical_name
				end)
			from openxml (@xdoc, '/MetaDataSnapshot/sys_master_files/row',1) 
				with (
					database_id int,
					[file_id] int,
					[type] tinyint,
					[physical_name] nvarchar(260),
					[name] sysname,
					[database_name] sysname,
					database_create_date datetime2(3)
				) mf

		inner join [dbo].[sqlwatch_meta_database] mdb
			on mdb.sql_instance = @sql_instance
			and mdb.database_name = convert(nvarchar(128),mf.database_name) collate database_default
			and mdb.database_create_date = mf.[database_create_date]
		) as source
	 on (
			source.file_id = target.file_id
		and source.[file_name] = target.[file_name] collate database_default
		and source.physical_name = target.file_physical_name collate database_default
		and	source.sql_instance = target.sql_instance
	 )

	when not matched by target then
		insert ( [sqlwatch_database_id], [file_id], [file_type], [file_physical_name], [sql_instance], [file_name], [logical_disk],[date_last_seen] )
		values ( source.[sqlwatch_database_id], source.[file_id], source.[type], source.[physical_name], source.[sql_instance], source.[file_name], source.[logical_disk], getutcdate() );
end;
		
