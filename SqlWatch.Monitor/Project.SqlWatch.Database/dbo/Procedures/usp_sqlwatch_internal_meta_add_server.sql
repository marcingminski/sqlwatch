CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_server]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on ;

	merge [dbo].[sqlwatch_meta_server] as target
	using (
		-- we should not need distinct here, but on rare ocassions I noticed C# is putting 3 rows into the dataset even thouhg only 1 row is at source!
		-- help.
		select distinct
			  [physical_name] 
			, [servername] 
			, [service_name]
			, [local_net_address] 
			, [local_tcp_port] 
			, [utc_offset_minutes] 
			, [sql_version]
		from openxml (@xdoc, '/MetaDataSnapshot/meta_server/row',1) 
			with (
				[physical_name] nvarchar(128),
				[servername] varchar(32),
				[service_name] nvarchar(128),
				[local_net_address] varchar(50),
				[local_tcp_port] varchar(50),
				[utc_offset_minutes] int ,
				[sql_version] nvarchar(2048)
			)	
		) as source
	on target.[servername] = source.[servername]

	when not matched then
		insert ([physical_name],[servername], [service_name], [local_net_address], [local_tcp_port], [utc_offset_minutes], [sql_version])
		values (source.[physical_name],source.[servername], source.[service_name], source.[local_net_address], source.[local_tcp_port], source.[utc_offset_minutes], source.[sql_version]);
end;