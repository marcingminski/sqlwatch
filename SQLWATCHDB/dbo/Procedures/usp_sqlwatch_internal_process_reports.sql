CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_reports] (
	@report_batch_id varchar(255) = null,
	@report_id smallint = null,
	@check_status nvarchar(50) = null,
	@check_value decimal(28,5) = null,
	@check_name nvarchar(max) = null,
	@subject nvarchar(max) = null,
	@body nvarchar(max) = null,
	--so we can apply filter to the reports:
	@check_threshold_warning varchar(100) = null,
	@check_threshold_critical varchar(100) = null
	)
as
/*
-------------------------------------------------------------------------------------------------------------------
 [usp_sqlwatch_internal_process_reports]

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/
SET NOCOUNT ON 
SET ANSI_NULLS ON


if @report_batch_id is null and @report_id is null
	begin
		raiserror('Either @report_batch_id or @report_id required',16,1)
	end

declare @sql_instance varchar(32),
		@report_title varchar(255),
		@report_description varchar(4000),
		@report_definition nvarchar(max),
		@delivery_target_id smallint,
		@definition_type varchar(25),

		@delivery_command nvarchar(max),
		@target_address nvarchar(max),
		@action_exec nvarchar(max),
		@action_exec_type nvarchar(max),
		@action_id smallint,

		@css nvarchar(max),
		@html nvarchar(max),
		@snapshot_type_id tinyint = 20,
		@snapshot_time datetime2(0),

		@error_message nvarchar(max) = '',
		@has_errored bit = 0,
		@report_last_run_date datetime,
		@report_current_run_date datetime,
		@report_current_run_date_utc datetime

declare @sqlwatch_logger_report_action table (
	 [sql_instance] varchar(32)
	,[snapshot_time] datetime2(0)
	,[snapshot_type_id] tinyint
	,[report_id] smallint
	,[action_id] smallint
	,[error_message] xml
)

exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id

declare cur_reports cursor for
select cr.[report_id]
      ,cr.[report_title]
      ,cr.[report_description]
      ,cr.[report_definition]
	  ,cr.[report_definition_type]
	  ,t.[action_exec]
	  ,t.[action_exec_type]
	  ,isnull(rs.style,'')
	  ,ra.action_id
	  ,mr.report_last_run_date
  from [dbo].[sqlwatch_config_report] cr

  inner join [dbo].[sqlwatch_config_report_action] ra
	on cr.report_id = ra.report_id

	inner join dbo.[sqlwatch_config_action] t
	on ra.[action_id] = t.[action_id]

	inner join [dbo].[sqlwatch_meta_report] mr
		on mr.report_id = cr.report_id
		and mr.sql_instance = @@SERVERNAME

	left join [dbo].[sqlwatch_config_report_style] rs
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

  and case /* no batch id passed, we are runing individual report */ when @report_batch_id is null then convert(varchar(255),@report_id) else @report_batch_id end = 
	case when @report_batch_id is null then convert(varchar(255),cr.[report_id]) else cr.[report_batch_id] end


order by cr.report_id

open cur_reports

fetch next from cur_reports
into @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css, @action_id, @report_last_run_date

while @@FETCH_STATUS = 0  
	begin

		delete from @sqlwatch_logger_report_action
		set @html = ''

		select @report_current_run_date = GETDATE(), @report_current_run_date_utc = GETUTCDATE()

		select @report_definition = replace(
										replace(
											replace(@report_definition,'{REPORT_LAST_RUN_DATE}',convert(varchar(23),@report_last_run_date,121)
											),'{REPORT_CURRENT_RUN_DATE}',convert(varchar(23),@report_current_run_date,121)
										),'{REPORT_CURRENT_RUN_DATE_UTC}',convert(varchar(23),@report_current_run_date_utc,121)
									)
		 
		/*	Query type does not get processed but is being passed straight into action for further processing i.e.
			in case we want to extract data to file:
			Invoke-SqlCmd -Query "{BODY}" | Out-File -Path .....
			Or for Azure Log Monitor Extractor	*/
		if @definition_type = 'Query'
			begin
				select 
					@body = @report_definition,
					@subject = @report_title

					GoTo QueueAction
			end



		if @check_status is not null
			begin
				set @report_definition = case 
					when @check_status = 'CRITICAL' and @check_threshold_critical is not null then replace(@report_definition,'{THRESHOLD}',@check_threshold_critical)
					when @check_status = 'WARNING' and @check_threshold_warning is not null then replace(@report_definition,'{THRESHOLD}',@check_threshold_warning)
					else @report_definition end
			end

		/*	Table type must be a single T-SQL query that will be converted into a HTML table	*/
		if @definition_type in ('HTML-Table','Table')
			begin
				begin try
					exec [dbo].[usp_sqlwatch_internal_query_to_html_table] @html = @html output, @query = @report_definition
				end try
				begin catch
					set @has_errored = 1
					set @error_message = 'Error when executing Query Report (usp_sqlwatch_internal_query_to_html_table), @report_batch_id: ' + isnull(convert(varchar(max),@report_batch_id),'NULL') + ', @report_id: ' + isnull(convert(varchar(max),@report_id),'NULL')
					exec [dbo].[usp_sqlwatch_internal_log]
							@proc_id = @@PROCID,
							@process_stage = '31FF6B08-735E-45F9-BAAB-D1F7E446BB1B',
							@process_message = @error_message,
							@process_message_type = 'ERROR'

					insert into @sqlwatch_logger_report_action ([sql_instance],[snapshot_time],[snapshot_type_id],[report_id],[action_id])
					select @@SERVERNAME,@snapshot_time,@snapshot_type_id,@report_id,@action_id

					GoTo NextReport
				end catch
			end

		/*	Template type is complex template that must produce an output ready to be passed into action, 
			i.e. a complete html report	*/
		if @definition_type in ('HTML-Template', 'Template')
			begin
				begin try
					exec sp_executesql @report_definition, N'@output nvarchar(max) OUTPUT', @output = @html output;
				end try
				begin catch
					--E3796F4B-3C89-450E-8FC7-09926979074F
					set @has_errored = 1
					set @error_message = 'Error when executing Template Report (usp_sqlwatch_internal_query_to_html_table), @report_batch_id: ' + isnull(convert(varchar(max),@report_batch_id),'NULL') + ', @report_id: ' + isnull(convert(varchar(max),@report_id),'NULL')
					exec [dbo].[usp_sqlwatch_internal_log]
							@proc_id = @@PROCID,
							@process_stage = 'E3796F4B-3C89-450E-8FC7-09926979074F',
							@process_message = @error_message,
							@process_message_type = 'ERROR'

					insert into @sqlwatch_logger_report_action ([sql_instance],[snapshot_time],[snapshot_type_id],[report_id],[action_id])
					select @@SERVERNAME,@snapshot_time,@snapshot_type_id,@report_id,@action_id

					GoTo NextReport
				end catch
			end

		select @css, @html
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
									replace(@body,'{REPORT_CONTENT}',isnull(@html,'Report Id: ' + convert(varchar(10),@report_id) + ' contains no data.'))
								,'{REPORT_TITLE}',@report_title)
							,'{REPORT_DESCRIPTION}',@report_description)
							
				set @subject = replace(@subject,'{REPORT_TITLE}',@report_title)
			end

		/*	If check is null it means we are not triggered report from the check.
			and if type = Query it means we are running a simple query. in this case
			add footer. 
			
			However, if we are here from the check or from "Template" based report, 
			the footers (as the whole content) are customisaible in the template */
		if @definition_type = 'Table' and @check_name is null 
			begin
				set @body = @body + '<p>Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
		<a href="https://sqlwatch.io">https://sqlwatch.io</a></p></body></html>'
			end

		QueueAction:

		update [dbo].[sqlwatch_meta_report]
			set [report_last_run_date] = @report_current_run_date_utc
		where [sql_instance] = @@SERVERNAME
		and [report_id] = @report_id

		set @action_exec = case @action_exec_type 
			/* for sql actions we have to escape quotes */
			when 'T-SQL' then replace(replace(@action_exec,'{BODY}', replace(@body,'''','''''')),'{SUBJECT}',@subject)
			else replace(replace(@action_exec,'{BODY}',@body),'{SUBJECT}',@subject)
		end

		if @action_exec is null
			begin
				Print 'Report (Id: ' + convert(varchar(255),@report_id) + ') @action_exec is NULL (Id: ' + convert(varchar(255),@action_id) + ')'
				GoTo NextReport
			end

		--now insert into the delivery queue for further processing:
		insert into [dbo].[sqlwatch_meta_action_queue] ([sql_instance], [time_queued], [action_exec_type], [action_exec])
		values (@@SERVERNAME, sysdatetime(), @action_exec_type, @action_exec)

		Print 'Item ( Id: ' + convert(varchar(10),SCOPE_IDENTITY()) + ' ) queued.'

		--E3796F4B-3C89-450E-8FC7-09926979074F
		insert into @sqlwatch_logger_report_action ([sql_instance],[snapshot_time],[snapshot_type_id],[report_id],[action_id])
		select @@SERVERNAME,@snapshot_time,@snapshot_type_id,@report_id,@action_id

		NextReport:

		insert into [dbo].[sqlwatch_logger_report_action]
		select [sql_instance], [snapshot_time], [snapshot_type_id], [report_id], [action_id] 
		from @sqlwatch_logger_report_action

		fetch next from cur_reports 
		into @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css, @action_id, @report_last_run_date

	end

close cur_reports
deallocate cur_reports


if @has_errored = 1
	begin
		set @error_message = 'Errors during execution of (' + OBJECT_NAME(@@PROCID) + '). Please review action log.'
		raiserror ('%s',16,1,@error_message)
	end