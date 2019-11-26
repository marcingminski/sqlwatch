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
				@tmp_table nvarchar(max)
		
		set nocount on;

		set @tmp_table = '##'+replace(convert(varchar(max),newid()),'-','')
		set @order_by = case when @order_by is null then '' else replace(@order_by, '''', '''''') end

		set @sql = 'select * into ' + @tmp_table + ' from (' + @query + ') t;'

		begin try
			exec sp_executesql @sql 
		end try
		begin catch
			select @error_message = @error_message + '
				' + convert(varchar(23),getdate(),121) + '
					 ERROR_NUMBER: ' + isnull(convert(varchar(10),ERROR_NUMBER()),'') + '
					 ERROR_SEVERITY : ' + isnull(convert(varchar(max),ERROR_SEVERITY()),'') + '
					 ERROR_STATE : ' + isnull(convert(varchar(max),ERROR_STATE()),'') + '   
					 ERROR_PROCEDURE : ' + isnull(convert(varchar(max),ERROR_PROCEDURE()),'') + '   
					 ERROR_LINE : ' + isnull(convert(varchar(max),ERROR_LINE()),'') + '   
					 ERROR_MESSAGE : ' + isnull(convert(varchar(max),ERROR_MESSAGE()),'') + ''
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
			select @error_message = @error_message + '
				' + convert(varchar(23),getdate(),121) + '
					 ERROR_NUMBER: ' + isnull(convert(varchar(10),ERROR_NUMBER()),'') + '
					 ERROR_SEVERITY : ' + isnull(convert(varchar(max),ERROR_SEVERITY()),'') + '
					 ERROR_STATE : ' + isnull(convert(varchar(max),ERROR_STATE()),'') + '   
					 ERROR_PROCEDURE : ' + isnull(convert(varchar(max),ERROR_PROCEDURE()),'') + '   
					 ERROR_LINE : ' + isnull(convert(varchar(max),ERROR_LINE()),'') + '   
					 ERROR_MESSAGE : ' + isnull(convert(varchar(max),ERROR_MESSAGE()),'') + ''
		end catch

		select @thead = coalesce(@thead + '', '') + '<th>' + name + '</th>' 
		from tempdb.sys.columns 
		where object_id = object_id('tempdb..' + @tmp_table)
		order by column_id;

		set @thead = '<tr><thead>' + @thead + '</tr></thead>';
		set @html = '<table class="sqlwatchtbl">' + @thead + '<tbody>' + @html + '</tbody></table>';    

	if nullif(@error_message,'') is not null
		begin
			set @error_message = 'Errors during execution (' + OBJECT_NAME(@@PROCID) + '): 
	' + @error_message
			set @html = '<p style="color:red;">' + @error_message + '</p>'
			--print all errors but not terminate the batch as we are going to include this error instead of the report for the attention.
			raiserror ('%s',1,1,@error_message)
		end
	end