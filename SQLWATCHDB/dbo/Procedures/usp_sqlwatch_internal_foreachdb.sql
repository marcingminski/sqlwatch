CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_foreachdb]
   @command nvarchar(max),
   @snapshot_type_id tinyint = null
as

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_internal_foreachdb

 Description:
	Iterate through databases i.e. improved replacement for sp_msforeachdb.

 Parameters
	@command	-	command to execute against each db, same as in sp_msforeachdb
	@snapshot_type_id	-	additionaly, if we are executing this in a collector, we can pass snapshot_id 
							in order to apply database/snapshot exlusion. This approach will prevent it
							from even accessing the database in the first place.
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-12		- Marcin Gminski, Initial version
-------------------------------------------------------------------------------------------------------------------
*/
begin
	set nocount on;
	declare @sql nvarchar(max),
			@db	nvarchar(max),
			@exclude_from_loop bit

	declare cur_database cursor
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR 
	select 
			sdb.[name]
		,	exclude_from_loop = case when ex.snapshot_type_id is not null then 1 else 0 end
	from dbo.vw_sqlwatch_sys_databases sdb

	--exclude database from looping through it:
	left join [dbo].[sqlwatch_config_exclude_database] ex
		on sdb.[name] like ex.database_name_pattern collate database_default
		and ex.snapshot_type_id = @snapshot_type_id

	open cur_database
	fetch next from cur_database into @db, @exclude_from_loop

	while @@FETCH_STATUS = 0
		begin
			if @exclude_from_loop = 0
				begin
					set @sql = ''
					set @db = @db

					set @sql = replace(@command,'?',@db)
			
					exec sp_executesql @sql
				end
			else
				begin
					Print 'Database (' + @db + ') excluded from collection (snapshot_type_id: ' + isnull(convert(varchar(10), @snapshot_type_id),'NULL') + ') due to global exclusion.'
				end
			fetch next from cur_database into @db, @exclude_from_loop
		end
end

