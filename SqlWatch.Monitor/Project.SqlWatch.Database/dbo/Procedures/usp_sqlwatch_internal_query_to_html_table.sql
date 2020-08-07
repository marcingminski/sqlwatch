	CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_query_to_html_table]
	(
	  @query nvarchar(MAX), 
	  @order_by nvarchar(MAX) = null, 
	  @html nvarchar(MAX) = null output 
	)

	as

	/* 
		If you are using custom css, please note the class name:
		<table class="sqlwatchtbl"
		-- based on https://stackoverflow.com/a/29708178
	*/

	begin   
		declare @sql nvarchar(max) = '',
				@error_message  nvarchar(max) = '',
				@thead nvarchar(max),
				@cols nvarchar(max),
				@tmp_table nvarchar(max),
				@error_message_single nvarchar(max) = '',
				@has_errors bit = 0
		
		set nocount on;

		set @tmp_table = '##'+replace(convert(varchar(max),newid()),'-','')
		set @order_by = case when @order_by is null then '' else replace(@order_by, '''', '''''') end

		set @sql = 'select * into ' + @tmp_table + ' from (' + @query + ') t;'

		begin try
			exec sp_executesql @sql 
		end try
		begin catch
			set @has_errors = 1

			set @error_message = 'Executing initial query'

			exec [dbo].[usp_sqlwatch_internal_log]
				@proc_id = @@PROCID,
				@process_stage = '77EF7172-3573-46B7-91E6-9BF0259B2DAC',
				@process_message = @error_message,
				@process_message_type = 'ERROR'
		end catch

		select @cols = coalesce(@cols + ', '''', ', '') + '[' + name + '] AS ''td'''
		from tempdb.sys.columns 
		where object_id = object_id('tempdb..' + @tmp_table)
		order by column_id;

		set @cols = 'set @html = cast(( select ' + @cols + ' from ' + @tmp_table + ' ' + @order_by + ' for xml path (''tr''), elements) as nvarchar(max))'    

		begin try
			exec sys.sp_executesql @cols, N'@html nvarchar(max) OUTPUT', @html=@html output
		end try
		begin catch

			set @has_errors = 1

			set @error_message = 'Building html content.'
			exec [dbo].[usp_sqlwatch_internal_log]
				@proc_id = @@PROCID,
				@process_stage = '52357550-B447-4352-9E0C-16353A967709',
				@process_message = @error_message,
				@process_message_type = 'ERROR'
		end catch

		select @thead = coalesce(@thead + '', '') + '<th>' + name + '</th>' 
		from tempdb.sys.columns 
		where object_id = object_id('tempdb..' + @tmp_table)
		order by column_id;

		set @thead = '<tr><thead>' + @thead + '</tr></thead>';
		set @html = '<table class="sqlwatchtbl">' + @thead + '<tbody>' + @html + '</tbody></table>';    

	if nullif(@error_message,'') is not null
		begin
			set @error_message = 'Errors during execution (' + OBJECT_NAME(@@PROCID) + ')'
			set @html = '<p style="color:red;">' + @error_message + '</p>'
			--print all errors but not terminate the batch as we are going to include this error instead of the report for the attention.
			raiserror ('%s',1,1,@error_message)
		end
	end