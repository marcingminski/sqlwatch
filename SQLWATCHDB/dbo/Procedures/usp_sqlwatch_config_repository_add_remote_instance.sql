CREATE PROCEDURE [dbo].[usp_sqlwatch_config_repository_add_remote_instance]
	@sql_instance varchar(32),
	@hostname nvarchar(32) = null,
	@sql_port int = null,
	@sqlwatch_database_name sysname,
	@environment sysname,
	@linked_server_name nvarchar(255) = null,
	@rmtuser nvarchar(128) = null,
	@rmtpassword nvarchar(128) = null
as


if @sql_instance = @@SERVERNAME
	begin
		raiserror ('Remote Instance is the same as local instance',16,1)
	end

merge [dbo].[sqlwatch_config_sql_instance] as target
using (
	select
		[sql_instance] = @sql_instance,
		[hostname] = @hostname,
		[sql_port] = @sql_port,
		[sqlwatch_database_name] = @sqlwatch_database_name,
		[environment] = @environment,
		[linked_server_name] = @linked_server_name,
		[repo_collector_is_active] = 1
	) as source

on source.sql_instance = target.sql_instance

when not matched then
	insert ([sql_instance],[hostname],[sql_port],[sqlwatch_database_name],[environment],[repo_collector_is_active],[linked_server_name])
	values (source.[sql_instance],source.[hostname],source.[sql_port],source.[sqlwatch_database_name],source.[environment],source.[repo_collector_is_active],source.[linked_server_name]);

IF @@ROWCOUNT > 0
	begin
		Print 'Added Remote SQL Instane (' + @sql_instance + ') to central repository.
If you are using linked server for data collection, please make sure these are also created. If you are using SSIS there is no more setup required.'
	end

if @linked_server_name is not null
	begin
		exec [dbo].[usp_sqlwatch_config_repository_create_linked_server]
			@sql_instance  = @sql_instance,
			@linked_server = @linked_server_name,
			@rmtuser = @rmtuser,
			@rmtpassword = @rmtpassword
	end
