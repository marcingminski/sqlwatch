CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_actions] (
	@sql_instance varchar(32) = @@SERVERNAME,
	@check_id smallint,
	@action_id smallint,
	@check_status varchar(50),
	@check_value decimal(28,5),
	@check_description nvarchar(max) = null,
	@check_name nvarchar(max),
	@check_threshold_warning varchar(100) = null,
	@check_threshold_critical varchar(100) = null,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@is_flapping bit = 0
	)
as

SET NOCOUNT ON 

/* 
-------------------------------------------------------------------------------------------------------------------
	[usp_sqlwatch_internal_process_actions]

	Abstract: 

	actions expect the following parameters:
	{SUBJECT} and {BODY}

	however, each can have its own template.
	for example, when using email action, we could have more content in the body
	and when using pushover we could limit it to most important informations.


	Version:
		1.0 2019-11--- - Marcin Gminski
------------------------------------------------------------------------------------------------------------------- 
*/

declare @action_type varchar(200) = 'NONE',
		@action_every_failure bit,
		@action_recovery bit,
		@action_repeat_period_minutes smallint,
		@action_hourly_limit tinyint,
		@action_template_id smallint,
		@last_action_time datetime,
		@action_count_last_hour smallint,
		@subject nvarchar(max),
		@body nvarchar(max),
		@subject_template nvarchar(max),
		@body_template nvarchar(max),
		@report_id smallint,
		@content_info varbinary(128),
		@error_message nvarchar(max),
		@error_message_single nvarchar(max) = '',
		@has_errors bit = 0,
		@action_template_type varchar(max),
		@action_exec_type varchar(max),
		@error_message_xml xml

--need to this so we can detect the caller in [usp_sqlwatch_internal_process_reports] to avoid circular ref.
select @content_info = convert(varbinary(128),convert(varchar(max),@action_id))
set CONTEXT_INFO @content_info

-------------------------------------------------------------------------------------------------------------------
-- Get action parameters:
-------------------------------------------------------------------------------------------------------------------
select 
		@action_every_failure = cca.[action_every_failure]
	,	@action_recovery = cca.[action_recovery]
	,	@action_repeat_period_minutes = cca.[action_repeat_period_minutes]
	,	@action_hourly_limit = cca.[action_hourly_limit]
	,	@action_template_id = cca.[action_template_id]
	,	@action_exec_type = ca.[action_exec_type]
from [dbo].[sqlwatch_config_check_action] cca
	inner join [dbo].[sqlwatch_config_action] ca
		on ca.action_id = cca.action_id
where cca.[check_id] = @check_id
and cca.[action_id] = @action_id

-------------------------------------------------------------------------------------------------------------------
-- each check has limit of actions per hour to avoid flooding:
-------------------------------------------------------------------------------------------------------------------
select 
	  @last_action_time = max([snapshot_time])
	, @action_count_last_hour = sum(case when [snapshot_time] > dateadd(hour,-1,getutcdate()) then 1 else 0 end)
from [dbo].[sqlwatch_logger_check_action]
where [check_id] = @check_id
and [action_id] = @action_id
and sql_instance = @@SERVERNAME


-------------------------------------------------------------------------------------------------------------------
-- skip actions for flapping cheks unless we expliclity want to action every failure:
-------------------------------------------------------------------------------------------------------------------
if @is_flapping = 1
	begin
		if @action_every_failure = 0
			begin
				--information only:
				set @error_message = 'Check (Id: ' + convert(varchar(10),@check_id) + ') Is flapping. Action (Id: ' + convert(varchar(10),@action_id) + ') is skipped.'
				exec [dbo].[usp_sqlwatch_internal_log]
						@proc_id = @@PROCID,
						@process_stage = '1D779244-0524-44B1-A00B-19BDA355D4EE',
						@process_message = @error_message,
						@process_message_type = 'WARNING'
				GoTo LogAction	
			end
		else
			begin
				set @error_message = 'Check (Id: ' + convert(varchar(10),@check_id) + ') Is flapping but @action_every_failure is set to 1. Action (Id: ' + convert(varchar(10),@action_id) + ') will be performed.'
				exec [dbo].[usp_sqlwatch_internal_log]
						@proc_id = @@PROCID,
						@process_stage = '43A6F442-2272-4953-81E7-B7014212BA29',
						@process_message = @error_message,
						@process_message_type = 'INFO'
			end
	end

-------------------------------------------------------------------------------------------------------------------
-- Get action details and add to the queue:
-------------------------------------------------------------------------------------------------------------------
if @action_count_last_hour > @action_hourly_limit
	begin
		--information only:
		set @error_message = 'Check (Id: ' + convert(varchar(10),@check_id) + '): Action (Id: ' + convert(varchar(10),@action_id) + ') has exceeded hourly allowed limit and it will not be performed.'
		exec [dbo].[usp_sqlwatch_internal_log]
				@proc_id = @@PROCID,
				@process_stage = '76C7745B-CDD2-4545-AF42-A3A5636D3F46',
				@process_message = @error_message,
				@process_message_type = 'WARNING'
		GoTo LogAction
	end


-------------------------------------------------------------------------------------------------------------------
-- We need to know if we are dealing with a new, repeated or recovered action. For this, we have to check
-- previous checks where action was requested
-------------------------------------------------------------------------------------------------------------------
select @action_type = case 

	-------------------------------------------------------------------------------------------------------------------
	-- when the current status is not OK and the previous status was OK, its a new notification:
	-------------------------------------------------------------------------------------------------------------------
	when @check_status <> 'OK' and isnull(last_check_status,'OK') = 'OK' then 'NEW'

	-------------------------------------------------------------------------------------------------------------------
	-- if previous status is NOT ok and current status is OK the check has recovered from fail to success.
	-- we can send an email notyfing DBAs that the problem has gone away
	-------------------------------------------------------------------------------------------------------------------
	when @check_status = 'OK' and isnull(last_check_status,'OK') <> 'OK' and @action_recovery = 1 then 'RECOVERY'

	-------------------------------------------------------------------------------------------------------------------
	-- retrigger if the value has changed and the status is not OK
	-- this is handy if we want to monitor every change after it has failed. for example we can set to monitor
	-- if number of logins is greater than 5 so if someone creates a new login we will get an email and then every time
	-- new login is created

	-- this however will not work in situations where we want a notification for ongoing blocking chains or failed jobs
	-- where there the count does not change. i.e. job A fails and then recovers but job B fails instead. The overall 
	-- count of jailed jobs at any given time is still 1. in such instance we can ste a reminder to 1 minute.
	-------------------------------------------------------------------------------------------------------------------
	when @check_status <> 'OK' and isnull(last_check_status,'OK') <> 'OK' 
		 and (last_check_value is null or @check_value <> last_check_value) and @action_every_failure = 1 then 'REPEAT'

	-------------------------------------------------------------------------------------------------------------------
	-- if the previous status is the same as the current status we would not normally send another email
	-- however, we can do if we set retrigger time. for example, we can be sending repeated alerts every hour so 
	-- they do not get forgotten about. 
	-------------------------------------------------------------------------------------------------------------------
	when @check_status <> 'OK' and last_check_status = @check_status and (@action_repeat_period_minutes is not null 
		and datediff(minute,isnull(@last_action_time,'1970-01-01'),getdate()) > @action_repeat_period_minutes) then 'REPEAT'

	else 'NONE' end
from [dbo].[sqlwatch_meta_check]
where [check_id] = @check_id
and sql_instance = @@SERVERNAME

-------------------------------------------------------------------------------------------------------------------
-- now we know what action we are dealing with, we can build template:
-------------------------------------------------------------------------------------------------------------------
select 
	 @subject_template = case @action_type 
			when 'NEW' then action_template_fail_subject
			when 'RECOVERY' then action_template_recover_subject
			when 'REPEAT' then action_template_repeat_subject
		else 'UNDEFINED' end
	,@body_template = case @action_type
			when 'NEW' then action_template_fail_body
			when 'RECOVERY' then action_template_recover_body
			when 'REPEAT' then action_template_repeat_body
		else 'UNDEFINED' end
	,@action_template_type = action_template_type
from [dbo].[sqlwatch_config_check_action_template]
where action_template_id = @action_template_id
--and sql_instance = @@SERVERNAME

/*  email clients do not handle <code> tags well so if we have any of these custom <codetable> in the description we will replace 
	with the below table. This is only so we do not store any HTML tags in the descriptions as they get pulled into PBI and can look ugly.
	And it makes writing html description easier. In the future this may get parameterised. */
set @check_description = 
	case when @action_template_type = 'HTML' then
		replace(
			replace(@check_description,
				'<code>','<table border=0 width="100%" cellpadding="10" style="display:block;background:#ddd; margin-top:1em;white-space: pre;"><tr><td><pre>'),
			'</code>','</pre></td></tr></table>')
		else @check_description end

-------------------------------------------------------------------------------------------------------------------
-- set {SUBJECT} and {BODY}
-------------------------------------------------------------------------------------------------------------------
if @action_type  <> 'NONE'
	begin
		--an action with arbitrary executable must have the following parameters:
		--{SUBJECT} and {BODY}
		--on top of it, an action will have a template that can have one of the below parameters so need to substitute them here:
		select @subject = 
			replace(
				replace(
					replace(
						replace(
							replace(
								replace(
									replace(
										replace(
											replace(
												replace(
													replace(
														replace(
															replace(
																replace(
																	replace(@subject_template,'{CHECK_STATUS}',@check_status)
																,'{CHECK_NAME}',check_name)
															,'{SQL_INSTANCE}',@@SERVERNAME)
														,'{CHECK_ID}',convert(varchar(max),cc.check_id))
													,'{CHECK_STATUS}',@check_status)
												,'{CHECK_VALUE}',convert(varchar(max),@check_value))
											,'{CHECK_LAST_VALUE}',isnull(convert(varchar(max),cc.last_check_value),'N/A'))
										,'{CHECK_LAST_STATUS}',isnull(cc.last_check_status,'N/A'))
									,'{LAST_STATUS_CHANGE}',isnull(convert(varchar(max),cc.last_status_change_date,121),'Never'))
								,'{CHECK_TIME}',convert(varchar(max),getdate(),121))
							,'{THRESHOLD_WARNING}',isnull(cc.check_threshold_warning,''))
						,'{THRESHOLD_CRITICAL}',isnull(cc.check_threshold_critical,''))
					,'{CHECK_DESCRIPTION}',isnull(rtrim(ltrim(case 
						when @action_exec_type = 'T-SQL' then replace(cc.check_description,'''','''''')
						when @action_exec_type = 'PowerShell' then replace(cc.check_description,'"','`"')
						end)),''))
				,'{CHECK_QUERY}',isnull(rtrim(ltrim(case
						when @action_exec_type = 'T-SQL' then replace(cc.check_query,'''','''''')
						when @action_exec_type = 'PowerShell' then replace(cc.check_query,'"','`"')
						end)),''))
			,'{SQL_VERSION}',@@VERSION)

			, @body = 
			replace(
				replace(
					replace(
						replace(
							replace(
								replace(
									replace(
										replace(
											replace(
												replace(
													replace(
														replace(
															replace(
																replace(
																	replace(@body_template,'{CHECK_STATUS}',@check_status)
																,'{CHECK_NAME}',check_name)
															,'{SQL_INSTANCE}',@@SERVERNAME)
														,'{CHECK_ID}',convert(varchar(max),cc.check_id))
													,'{CHECK_STATUS}',@check_status)
												,'{CHECK_VALUE}',convert(varchar(max),@check_value))
											,'{CHECK_LAST_VALUE}',isnull(convert(varchar(max),cc.last_check_value),'N/A'))
										,'{CHECK_LAST_STATUS}',isnull(cc.last_check_status,'N/A'))
									,'{LAST_STATUS_CHANGE}',isnull(convert(varchar(max),cc.last_status_change_date,121),'Never'))
								,'{CHECK_TIME}',convert(varchar(max),getdate(),121))
							,'{THRESHOLD_WARNING}',isnull(cc.check_threshold_warning,'None'))
						,'{THRESHOLD_CRITICAL}',isnull(cc.check_threshold_critical,''))
					,'{CHECK_DESCRIPTION}',isnull(rtrim(ltrim(case 
						when @action_exec_type = 'T-SQL' then replace(cc.check_description,'''','''''')
						when @action_exec_type = 'PowerShell' then replace(cc.check_description,'"','`"')
						end)),''))
				,'{CHECK_QUERY}',isnull(rtrim(ltrim(case
						when @action_exec_type = 'T-SQL' then replace(cc.check_query,'''','''''')
						when @action_exec_type = 'PowerShell' then replace(cc.check_query,'"','`"')
						end)),''))
			,'{SQL_VERSION}',@@VERSION)
			

		from [dbo].[sqlwatch_meta_check] cc
		where cc.check_id = @check_id
		and cc.sql_instance = @@SERVERNAME

		insert into [dbo].[sqlwatch_meta_action_queue] (sql_instance, [action_exec_type], [action_exec])
		select @@SERVERNAME, [action_exec_type], replace(replace([action_exec],'{SUBJECT}',@subject),'{BODY}',@body)
		from [dbo].[sqlwatch_config_action]
		where action_id = @action_id
		and [action_enabled] = 1
		and [action_exec] is not null --null action exec can only be for reports but they are processed below

		--is this action calling a report or an arbitrary exec?
		select @report_id = action_report_id 
		from [dbo].[sqlwatch_config_action] where action_id = @action_id

		if @report_id is not null
			begin
				--if we have action that calls a report, call the report here:
				begin try
					exec [dbo].[usp_sqlwatch_internal_process_reports] 
						 @report_id = @report_id
						,@check_status = @check_status
						,@check_value = @check_value
						,@check_name = @check_name
						,@subject = @subject
						,@body = @body
						,@check_threshold_warning = @check_threshold_warning
						,@check_threshold_critical = @check_threshold_critical
				end try
				begin catch
					set @has_errors = 1		
					set @error_message = 'Action (Id:' + convert(varchar(10),@action_id) + ') calling Report (Id: ' + convert(varchar(10),@report_id) + ')'
					exec [dbo].[usp_sqlwatch_internal_log]
						@proc_id = @@PROCID,
						@process_stage = 'F7A4AA65-1BE9-4D0B-8B1F-054CA1E24A6E',
						@process_message = @error_message,
						@process_message_type = 'ERROR'

					--select @error_message_xml = [dbo].[ufn_sqlwatch_get_error_detail_xml](
					--	@@PROCID,'F7A4AA65-1BE9-4D0B-8B1F-054CA1E24A6E','exec [dbo].[usp_sqlwatch_internal_process_reports] @report_id=' + convert(varchar(10),@report_id) + ' @action_id=' + convert(varchar(10),@action_id)
					--	)
				end catch
			end
	end

 LogAction:

--log action for each check. This is so we can track how many actions are being executed per each check to satisfy 
--the [action_hourly_limit] parameter and to have an overall visibility of what checks trigger what actions. 
--This table needs a minimum of 1 hour history.
if @action_type <> 'NONE'
	begin
		insert into [dbo].[sqlwatch_logger_check_action] ([sql_instance], [snapshot_type_id], [check_id], [action_id], [snapshot_time], [action_attributes])
		select @@SERVERNAME, @snapshot_type_id, @check_id, @action_id, @snapshot_time, (
			select *
			from (
				select	'ContentInfo' = @action_id,
						'ActionEveryFailure' = @action_every_failure,
						'ActionRecovery' = @action_recovery,
						'ActionRepeatPeriodMinutes' = @action_repeat_period_minutes,
						'ActionHourlyLimit' = @action_hourly_limit,
						'ActionTemplateId' = @action_template_id,
						'LastActionTime' = @last_action_time,
						'ActionCountLastHour' = @action_count_last_hour,
						'ActionType' = @action_type,
						'ReportId' = @report_id,
						'Subject' = @subject,
						'Body' = @body
			) a
			for xml path('Attributes'))
	end

if @has_errors = 1
	begin
		set @error_message = 'Errors during action execution (' + OBJECT_NAME(@@PROCID) + '): 
' + @error_message

		--print all errors and terminate the batch which will also fail the agent job for the attention:
		raiserror ('%s',16,1,@error_message)
	end