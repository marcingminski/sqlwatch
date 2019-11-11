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
	declare @sql nvarchar(max) = ''
	
	set nocount on;
	set @order_by = case when @order_by is null then '' else replace(@order_by, '''', '''''') end

	set @sql = '
    declare @thead nvarchar(max),
			@cols nvarchar(max);    

	select * into #t from (' + @query + ') t;

	select @cols = coalesce(@cols + '', '''''''', '', '''') + ''['' + name + ''] AS ''''td''''''
    from tempdb.sys.columns 
    where object_id = object_id(''tempdb..#t'')
    order by column_id;

	' + /* set @cols = ''set @html = cast(( select '' + @cols + '' from #t ' + @order_by + ' for xml path (''''tr''''), elements XSINIL) as nvarchar(max))''  */ + '
    set @cols = ''set @html = cast(( select '' + @cols + '' from #t ' + @order_by + ' for xml path (''''tr''''), elements) as nvarchar(max))''    

    exec sys.sp_executesql @cols, N''@html nvarchar(max) OUTPUT'', @html=@html output

    select @thead = coalesce(@thead + '''', '''') + ''<th>'' + name + ''</th>'' 
    from tempdb.sys.columns 
    where object_id = object_id(''tempdb..#t'')
    order by column_id;

    set @thead = ''<tr><thead>'' + @thead + ''</tr></thead>'';
    set @html = ''<table class="sqlwatchtbl">'' + @thead + ''<tbody>'' + @html + ''</tbody></table>'';    
    ';

  exec sys.sp_executesql @sql, N'@html nvarchar(MAX) output', @html=@html output
end