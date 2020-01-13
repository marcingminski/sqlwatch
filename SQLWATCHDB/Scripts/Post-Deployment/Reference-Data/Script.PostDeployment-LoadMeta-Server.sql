/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
begin transaction
	/* add local instance to server config so we can satify relations */
	merge dbo.sqlwatch_config_sql_instance as target
	using (select [servername] = @@SERVERNAME, [repo_collector_is_active] = 0) as source
	on target.sql_instance = source.[servername]
	when not matched then
		insert (sql_instance, [repo_collector_is_active])
		values (source.[servername], source.[repo_collector_is_active]);

	merge [dbo].[sqlwatch_meta_server] as target
	using (
		select [physical_name] = convert(sysname,SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
			, [servername] = convert(sysname,@@SERVERNAME)
			, [service_name] = convert(sysname,@@SERVICENAME)
			, [local_net_address] = convert(varchar(50),local_net_address)
			, [local_tcp_port] = convert(varchar(50),local_tcp_port)
			, [utc_offset_minutes] = DATEDIFF(mi, GETUTCDATE(), GETDATE())
			, [sql_version] = @@VERSION
		from sys.dm_exec_connections where session_id = @@spid
		) as source
	on target.[servername] = source.[servername]

	when not matched then
		insert ([physical_name],[servername], [service_name], [local_net_address], [local_tcp_port], [utc_offset_minutes], [sql_version])
		values (source.[physical_name],source.[servername], source.[service_name], source.[local_net_address], source.[local_tcp_port], source.[utc_offset_minutes], source.[sql_version])

		;
commit transaction