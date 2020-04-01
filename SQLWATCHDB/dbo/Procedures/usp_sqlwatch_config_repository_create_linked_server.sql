CREATE PROCEDURE [dbo].[usp_sqlwatch_config_repository_create_linked_server]
	@sql_instance varchar(32) = null,
	@linked_server nvarchar(128) = null,
	@rmtuser nvarchar(128) = null,
	@rmtpassword nvarchar(128) = null
as

	if @rmtuser is not null and @rmtpassword is null
		begin
			raiserror ('@rmtpassword must be specified when @rmtuser is specified.',16,1)
		end

	set xact_abort on;
	set nocount on;
	
	declare @table_name nvarchar(max),
			@table_schema nvarchar(max),
			@sql_1 nvarchar(max),
			@hostname nvarchar(max),
			@error_message nvarchar(max),
			@sqlwatch_database_name nvarchar(max),
			@has_errors bit = 0


	--create required linked servers here:
	declare cur_ls cursor for
	select sql_instance
	from [dbo].[sqlwatch_config_sql_instance]
	where [repo_collector_is_active] = 1
	and sql_instance = isnull(@sql_instance,sql_instance)
	and sql_instance <> @@SERVERNAME

	open cur_ls

	fetch next from cur_ls into @sql_instance

	while @@FETCH_STATUS = 0
		begin

			if @linked_server is null
				begin
					set @linked_server = 'SQLWATCH-REMOTE-' + @sql_instance
				end

			/* if no linked servers in the config table, add it first */
			update dbo.sqlwatch_config_sql_instance
				set linked_server_name = @linked_server
			where  linked_server_name is null
			and sql_instance = @sql_instance

			select @hostname = isnull(hostname, sql_instance), @sqlwatch_database_name = sqlwatch_database_name, @linked_server = linked_server_name
			from [dbo].[sqlwatch_config_sql_instance]
			where sql_instance = @sql_instance

			if exists (
				select * from sys.servers
				where name = @linked_server
				and is_linked = 1
				)
				begin
					exec dbo.sp_dropserver @server=@linked_server, @droplogins='droplogins'
				end

			--sp_addlinkedserver cannot be executed within a user-defined transaction.
			--https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-addlinkedserver-transact-sql

			exec dbo.sp_addlinkedserver @server = @linked_server, @srvproduct=N'', @provider=N'SQLNCLI11', @datasrc=@hostname
			exec dbo.sp_addlinkedsrvlogin @rmtsrvname = @linked_server , @locallogin = NULL , @useself = N'False', @rmtuser = @rmtuser, @rmtpassword = @rmtpassword
			exec dbo.sp_serveroption @server=@linked_server, @optname=N'connect timeout', @optvalue=N'60'

			Print 'Created Linked Server (' + @linked_server + ') for ' + @sql_instance + ' (' + @hostname + ')'

			fetch next from cur_ls into @sql_instance
		end






