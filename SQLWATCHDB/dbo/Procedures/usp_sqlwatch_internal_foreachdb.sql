CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_foreachdb]
   @command nvarchar(max),
   @snapshot_type_id tinyint = null,
   @exlude_databases varchar(max) = null,
   @debug bit = 0
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
	@exlude_databases	-	list of comma separated database names to exclude from the loop
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-12		- Marcin Gminski, Initial version
	1.1		2019-12-10	- Marcin Gminski, database exclusion
	1.2		2012-12-23	- Marcin Gminski, added error handling and additional messaging
-------------------------------------------------------------------------------------------------------------------
*/
begin
	set nocount on;
	declare @sql nvarchar(max),
			@db	nvarchar(max),
			@exclude_from_loop bit,
			@has_errors bit = 0,
			@error_message nvarchar(max)

	select *
	into #t
	from [dbo].[ufn_sqlwatch_split_string] (@exlude_databases,',')

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

					if not exists (
						select * from #t
						where @db like [value] collate database_default
						)
						begin
							set @sql = replace(@command,'?',@db)
							Print 'Processing database: ' + quotename(@db)
							begin try
								if @debug = 1
									begin
										Print @sql
									end
								exec sp_executesql @sql
							end try
							begin catch
								set @has_errors = 1
								if @@trancount > 0
									rollback

								exec [dbo].[usp_sqlwatch_internal_log]
										@proc_id = @@PROCID,
										@process_stage = 'F445D2BC-2CF3-4F41-9284-A4C3ACA513EB',
										@process_message = @sql,
										@process_message_type = 'ERROR'
								GoTo NextDatabase
							end catch
						end
					else
						begin
							Print 'Database (' + @db + ') excluded from collection due to local exclusion'
						end
				end
			else
				begin
					Print 'Database (' + @db + ') excluded from collection (snapshot_type_id: ' + isnull(convert(varchar(10), @snapshot_type_id),'NULL') + ') due to global exclusion.'
				end
			NextDatabase:
			fetch next from cur_database into @db, @exclude_from_loop
		end

		if @has_errors <> 0
			begin
				set @error_message = 'Errors during execution (' + OBJECT_NAME(@@PROCID) + ')'
				raiserror ('%s',16,1,@error_message)
			end
end

