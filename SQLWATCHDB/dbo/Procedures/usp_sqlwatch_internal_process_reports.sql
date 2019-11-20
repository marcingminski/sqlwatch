CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_reports] (
	@report_batch_id tinyint = null,
	@report_id smallint = null,
	@check_status nvarchar(50) = null,
	@check_value decimal(28,2) = null,
	@check_name nvarchar(max) = null,
	@subject nvarchar(max) = null,
	@body nvarchar(max) = null
	)
as
/*
-------------------------------------------------------------------------------------------------------------------
 [usp_sqlwatch_internal_process_reports]

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/
set nocount on;
set xact_abort on;

declare @sql_instance varchar(32),
		@report_title varchar(255),
		@report_description varchar(4000),
		@report_definition nvarchar(max),
		@delivery_target_id smallint,
		@definition_type varchar(10),

		@delivery_command nvarchar(max),
		@target_address nvarchar(max),
		@action_exec nvarchar(max),
		@action_exec_type nvarchar(max),

		@css nvarchar(max),
		@html nvarchar(max)

declare @template_build as table (
	[result] nvarchar(max)
)


declare cur_reports cursor for
select cr.[report_id]
      ,[report_title]
      ,[report_description]
      ,[report_definition]
	  ,[report_definition_type]
	  ,t.[action_exec]
	  ,t.[action_exec_type]
	  ,rs.style
  from [dbo].[sqlwatch_config_report] cr

  inner join [dbo].[sqlwatch_config_report_action] ra
	on cr.report_id = ra.report_id

	inner join dbo.[sqlwatch_config_action] t
	on ra.[action_id] = t.[action_id]

	inner join [dbo].[sqlwatch_config_report_style] rs
		on rs.report_style_id = cr.report_style_id

  where [report_active] = 1
  and t.[action_enabled] = 1

  --and isnull([report_batch_id],0) = isnull(@report_batch_id,0)
  --and cr.report_id = isnull(@report_id,cr.report_id)
  --avoid getting a report that calls actions that has called this routine to avoid circular refernce:
    and convert(varchar(128),ra.action_id) <> isnull(convert(varchar(128),CONTEXT_INFO()),'0')

  --we must either run report by id or by batch. a null batch_id will indicate that we only run report by its id, usually triggred by an action
  --a batch_id indicates that we run reports from a batch job, i.e. some daily scheduled server summary reports etc, something that is not triggered by an action.
  --remember, an action is triggred on the back of a failed check so unsuitable for a "scheduled daily reports"

  and case /* no batch id passed, we are runing individual report */ when @report_batch_id is null then @report_id else @report_batch_id end = case when @report_batch_id is null then cr.[report_id] else cr.[report_batch_id] end
		
open cur_reports

fetch next from cur_reports
into @sql_instance, @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css

while @@FETCH_STATUS = 0  
	begin
		set @html = ''

		delete from @template_build

		if @definition_type = 'Query'
			begin
				exec [dbo].[usp_sqlwatch_internal_query_to_html_table] @html = @html output, @query = @report_definition
			end

		if @definition_type = 'Template'
			begin
				insert into @template_build
				exec sp_executesql @report_definition

				select @html = [result] from @template_build
			end

		set @html = '<html><head><style>' + @css + '</style><body>' + @html

		--if @check_name is NOT null it means report has been triggered by a check action. Therefore, we need to respect the check action template:
		if charindex('{REPORT_CONTENT}',isnull(@body,'')) = 0
			begin
				--body content was either not passed or does not contain '{REPORT_CONTENT}'. In this case we are just going to include the report as the body.
				set @body = @html + case when @report_description is not null then '<p>' + @report_description + '</p>' else '' end 
				set @subject = @report_title
			end
		else
			begin
				set @body = replace(
								replace(
									replace(@body,'{REPORT_CONTENT}',@html)
								,'{REPORT_TITLE}',@report_title)
							,'{REPORT_DESCRIPTION}',@report_description)

				set @subject = replace(@subject,'{REPORT_TITLE}',@report_title)
			end

		/*	If check is null it means we are not triggered report from the check.
			and if type = Query it means we are running a simple query. in this case
			add footer. 
			
			However, if we are here from the check or from "Template" based report, 
			the footers (as the whole content) are customisaible in the template */
		if @definition_type = 'Query' and @check_name is null 
			begin
				set @body = @body + '<p>Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
		<a href="https://sqlwatch.io">https://sqlwatch.io</a></p></body></html>'
			end

		if @body is null
			begin
				set @body = 'Report Id: ' + convert(varchar(10),@report_id) + ' contains no data.'
			end

		if @subject is null
			begin
				set @subject = 'No Subject'
			end

		set @action_exec = replace(replace(@action_exec,'{BODY}', replace(@body,'''','''''')),'{SUBJECT}',@subject)
		--now insert into the delivery queue for further processing:
		insert into [dbo].[sqlwatch_meta_action_queue] ([sql_instance], [time_queued], [action_exec_type], [action_exec])
		values (@@SERVERNAME, sysdatetime(), @action_exec_type, @action_exec)

		Print 'Item ( Id: ' + convert(varchar(10),SCOPE_IDENTITY()) + ' ) queued.'

		fetch next from cur_reports 
		into @sql_instance, @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css

	end

close cur_reports
deallocate cur_reports