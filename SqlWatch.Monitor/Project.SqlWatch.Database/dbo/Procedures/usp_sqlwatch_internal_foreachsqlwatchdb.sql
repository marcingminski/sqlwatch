CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_foreachsqlwatchdb]
	@command nvarchar(max),
	@replacechar nchar(1) = N'?',
	@exclude_tempdb bit = 0
as

-- a simplified version of usp_sqlwatch_internal_foreachdb intended to run on the remote instance via collector and only interate through 
-- databases defined in vw_sqlwatch_sys_databases
-- insipired by https://spaghettidba.com/2011/09/09/a-better-sp_msforeachdb/
set nocount on;

declare @db	nvarchar(max),
		@sql nvarchar(max);

declare cur_database cursor
LOCAL FORWARD_ONLY STATIC READ_ONLY
FOR 
select distinct sdb.name
from dbo.vw_sqlwatch_sys_databases sdb;

open cur_database;

fetch next from cur_database into @db;

while @@FETCH_STATUS = 0
	begin
		if @db <> 'tempdb' or (@db = 'tempdb' and @exclude_tempdb = 0)
			begin
				set @sql = replace(@command,'?',@db);
				exec sp_executesql @sql;				
			end

		fetch next from cur_database into @db;
	end;

close cur_database;
deallocate cur_database;