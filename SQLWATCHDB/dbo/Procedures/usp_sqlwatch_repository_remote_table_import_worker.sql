CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_remote_table_import_worker]
	@sql_instance varchar(32),
	@object_name nvarchar(512),
	@load_type char(1)

as


declare @sql nvarchar(max),
		@sql_remote nvarchar(max),
		@snapshot_time_start datetime2(0),
		@snapshot_time_end datetime2(0),
		@snapshot_type_id tinyint,
		@ls_server nvarchar(128),

		@join_keys nvarchar(max),
		@has_identity bit = 0,
		@table_name nvarchar(128),
		@table_schema nvarchar(128),
		@all_columns nvarchar(max),
		@all_columns_from_source nvarchar(max),
		@all_columns_to_destination nvarchar(max),
		@pk_columns nvarchar(max),
		@nonpk_columns nvarchar(max),
		@has_errors bit = 0,
		@message nvarchar(max),
		@rmtq_timestart datetime2(7),
		@rmtq_timeend datetime2(7),
		@rowcount_imported bigint,
		@rowcount_loaded bigint,
		@update_columns nvarchar(max)


		select 
			@table_name = parsename(@object_name,1),
			@table_schema = parsename(@object_name,2)


				select @ls_server = linked_server_name
				from [dbo].[sqlwatch_config_sql_instance]
				where sql_instance = @sql_instance
				and linked_server_name is not null
				and repo_collector_is_active = 1

				/* get primary keys */
				select  @pk_columns = stuff ((
							select ',' + quotename(ccu.COLUMN_NAME)
								from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
								inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
								on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
							where tc.TABLE_NAME = @table_name 
							and tc.CONSTRAINT_TYPE = 'Primary Key'
							order by ccu.ORDINAL_POSITION
							for xml path('')),1,1,'')


				/* non primary key columns */
				select @nonpk_columns = stuff((
						select ',' + quotename(COLUMN_NAME)
						from INFORMATION_SCHEMA.COLUMNS
						where TABLE_NAME = @table_name

						and COLUMN_NAME not in (
								select ccu.COLUMN_NAME
								from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
								inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
								on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
								where tc.TABLE_NAME = @table_name
								and tc.CONSTRAINT_TYPE = 'Primary Key'
						)
						order by ORDINAL_POSITION
						for xml path('')),1,1,'')


				/* get columns */
				select @all_columns = stuff ((
						select ',' + quotename(COLUMN_NAME)
						from INFORMATION_SCHEMA.COLUMNS
						where TABLE_NAME = @table_name
						order by ORDINAL_POSITION
						for xml path('')),1,1,'')

				/* get columns, linked servers do not support xml data type so we need to convert to char and back to xml */
				select @all_columns_from_source = stuff ((
						select ',' + case when DATA_TYPE like '%xml%' then quotename(COLUMN_NAME) + ' = convert(nvarchar(max),' + quotename(COLUMN_NAME) + ')' else quotename(COLUMN_NAME) end
						from INFORMATION_SCHEMA.COLUMNS
						where TABLE_NAME = @table_name
						order by ORDINAL_POSITION
						for xml path('')),1,1,'')

				select @all_columns_to_destination = stuff ((
						select ',' + case when DATA_TYPE like '%xml%' then quotename(COLUMN_NAME) + ' = convert(xml,' + quotename(COLUMN_NAME) + ')' else quotename(COLUMN_NAME) end
						from INFORMATION_SCHEMA.COLUMNS
						where TABLE_NAME = @table_name
						order by ORDINAL_POSITION
						for xml path('')),1,1,'')


				/* update columns */
				select @update_columns = stuff((
						select ',' + quotename(COLUMN_NAME) + '=source.' + quotename(COLUMN_NAME)
						from INFORMATION_SCHEMA.COLUMNS
						where TABLE_NAME = @table_name

						and COLUMN_NAME not in (
								select ccu.COLUMN_NAME
								from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
								inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
								on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
								where tc.TABLE_NAME = @table_name
								and tc.CONSTRAINT_TYPE = 'Primary Key'
						)
						order by ORDINAL_POSITION
						for xml path('')),1,1,'')


				/* build joins */
				select @join_keys = stuff ((
							select ' and source.' + quotename(ccu.COLUMN_NAME) + ' = target.' + quotename(ccu.COLUMN_NAME)
								from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
								inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
								on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
							where tc.TABLE_NAME = @table_name AND 
							tc.CONSTRAINT_TYPE = 'Primary Key'
							order by ccu.ORDINAL_POSITION
							for xml path('')),1,5,'')

				/* check is table has identity */
				select @has_identity = isnull(( 
					select 1
					from SYS.IDENTITY_COLUMNS 
					where OBJECT_NAME(OBJECT_ID) = @table_name
					),0)







			------------------------------------------------------------------------------------------------------------
			-- FULL LOAD
			------------------------------------------------------------------------------------------------------------
			if @load_type = 'F'
				begin
					set @sql = 'select ' + @all_columns_from_source + ' from ' + @object_name
					set @sql = '
select ' + @all_columns_to_destination + ' 
into #t
from openquery([' + @ls_server + '],''' + replace(@sql,'''','''''') + ''')
set @rowcount_imported_out = @@ROWCOUNT

alter table #t add primary key (' + @pk_columns + ');

' + case when @has_identity = 1 then 'set identity_insert ' + quotename(@table_name) + ' on' else '' end + '
;merge ' + quotename(@table_name) + ' as target
using #t as source 
on ( ' + @join_keys + ' )

when matched
	then update set ' 
	+ @update_columns + '
		
when not matched 
	then insert ( ' + @all_columns + ')
	values ( source.' + replace(@all_columns,',',',source.') + ')
;
set @rowcount_loaded_out = @@ROWCOUNT
' + case when @has_identity = 1 then 'set identity_insert ' + quotename(@table_name) + ' off' else '' end + '
;

'				


				end




			------------------------------------------------------------------------------------------------------------
			-- DELTA LOAD
			------------------------------------------------------------------------------------------------------------
			if @load_type = 'D'
				begin
					select @snapshot_type_id = snapshot_type_id
					from vw_sqlwatch_internal_table_snapshot
					where table_name = parsename(@object_name,1)

					/*	get current max snapshot_time to calcualte delta from remote	*/
					set @sql = 'select @snapshot_time_start_out = max(snapshot_time) from ' + @object_name + ' where sql_instance = ''' + @sql_instance + ''''
					
					begin try
						exec sp_executesql @sql , N'@snapshot_time_start_out datetime2(0) OUTPUT', @snapshot_time_start_out = @snapshot_time_start output;
					end try
					begin catch
						exec [dbo].[usp_sqlwatch_internal_log]
							@proc_id = @@PROCID,
							@process_stage = '985164F4-C2E8-49F9-A582-E4CDF5385406',
							@process_message = @sql,
							@process_message_type = 'ERROR'
					end catch
					/*	get current max snapshot_time from the header so we are not trying to insert any data that is not yet in the header */
					set @sql = 'select @snapshot_time_end_out = max(snapshot_time) 
from dbo.sqlwatch_logger_snapshot_header
where sql_instance = ''' + @sql_instance + '''
and snapshot_type_id = ' + convert(varchar(10),@snapshot_type_id)

					begin try
						exec sp_executesql @sql, N'@snapshot_time_end_out datetime2(0) OUTPUT', @snapshot_time_end_out = @snapshot_time_end output;
					end try
					begin catch
						exec [dbo].[usp_sqlwatch_internal_log]
							@proc_id = @@PROCID,
							@process_stage = 'CCEC28A0-4F4A-4BA2-B17A-CF59434F77ED',
							@process_message = @sql,
							@process_message_type = 'ERROR'
					end catch
				
					/*	build the remote command limited to dates from the above calcualations	*/
					set @sql = 'select ' + @all_columns_from_source + ' from ' + @object_name + '
where sql_instance = ''' + @sql_instance + ''' 
and snapshot_time > ''' + isnull( convert(varchar(23),@snapshot_time_start,121),'1970-01-01') + '''
' 
/* we want to pull all new headers , all the other logger tables we are pulling new records but limited to the most recent header */
+ case when @table_name <> 'sqlwatch_logger_snapshot_header' then 'and snapshot_time <= ''' + isnull( convert(varchar(23),@snapshot_time_end,121), '1970-01-01') + '''' else '' end

					set @sql = '
' + case when @has_identity = 1 then 'set identity_insert ' + quotename(@table_name) + ' on' else '' end + '
insert into '+ quotename(@table_schema) + '.' + quotename(@table_name) + ' (' + @all_columns + ')
select ' + @all_columns_to_destination + ' from openquery([' + @ls_server + '],''' + replace(@sql,'''','''''') + ''')
set @rowcount_loaded_out = @@ROWCOUNT
' + case when @has_identity = 1 then 'set identity_insert ' + quotename(@table_name) + ' off' else '' end + '
					'
				end

		select @rowcount_imported = null, @rowcount_loaded = null

		if @sql is null
			begin
				return
			end

			set @rmtq_timestart = sysutcdatetime()
			begin try
				exec sp_executesql @sql, N'@rowcount_imported_out bigint OUTPUT, @rowcount_loaded_out bigint OUTPUT', @rowcount_imported_out = @rowcount_imported output, @rowcount_loaded_out = @rowcount_loaded output;
			end try
			begin catch
				exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = '9B115374-36F7-484F-810F-8B9EB2307342',
					@process_message = @sql,
					@process_message_type = 'ERROR'
			end catch
			set @rmtq_timeend = sysutcdatetime()
					
			set @message = 'Retrieving data from remote instance (' + @sql_instance + '). '
			set @message = @message + case when @rowcount_imported is not null then 'Imported ' + convert(varchar(10),@rowcount_imported) + ' rows from remote table (' + @object_name + '). ' else '' end
			set @message = @message + case when @rowcount_loaded is not null then 'Loaded ' + convert(varchar(10),@rowcount_loaded) + ' rows into local table (' + @table_name + '). ' else '' end

			set @message = @message + 'Time Start: ' + convert(varchar(23),@rmtq_timestart,121) + ', Time End: ' + convert(varchar(23),@rmtq_timeend,121) + ', Time Taken (ms): ' + convert(varchar(10),datediff(ms,@rmtq_timestart,@rmtq_timeend),121)

			exec [dbo].[usp_sqlwatch_internal_log]
				@proc_id = @@PROCID,
				@process_stage = '11592B38-3F3F-4E91-87ED-6C7DD0CDC483',
				@process_message = @message,
				@process_message_type = 'INFO'

