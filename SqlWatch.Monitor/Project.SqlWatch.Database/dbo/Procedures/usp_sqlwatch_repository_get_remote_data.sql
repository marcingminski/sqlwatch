CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_get_remote_data]
	@sql nvarchar(max),
	@sql_instance varchar(32)
AS
BEGIN

	--set xact_abort on;
	--set nocount on;
	
	--declare @ls_server nvarchar(max),
	--		@table_name nvarchar(max),
	--		@table_schema nvarchar(max),
	--		@sql_1 nvarchar(max),
	--		@hostname nvarchar(max),
	--		@error_message nvarchar(max),
	--		@sqlwatch_database_name nvarchar(max),
	--		@has_errors bit = 0


	--		set @has_errors = 0

	--		select @hostname = isnull(hostname, sql_instance), @sqlwatch_database_name = sqlwatch_database_name
	--		from [dbo].[sqlwatch_config_sql_instance]
	--		where sql_instance = @sql_instance

			

	--				set @sql = 'select * from openquery([' + @ls_server + '],''' + replace(@sql,'''','''''') + ''')'

	--				select @sql


	--				--exec sp_executesql @sql


SELECT CONVERT(INT,'am I used?')


END
