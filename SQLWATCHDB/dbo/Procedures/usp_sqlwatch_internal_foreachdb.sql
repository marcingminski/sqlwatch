CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_foreachdb]
   @command nvarchar(max)
as
begin
	set nocount on;
	declare @sql nvarchar(max),
			@db	nvarchar(max)

	declare cur_database cursor
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR 
	select [name]
	from dbo.vw_sqlwatch_sys_databases

	open cur_database
	fetch next from cur_database into @db

	while @@FETCH_STATUS = 0
		begin
			set @sql = ''
			set @db = @db

			set @sql = replace(@command,'?',@db)
			
			exec sp_executesql @sql
			fetch next from cur_database into @db
		end
end

