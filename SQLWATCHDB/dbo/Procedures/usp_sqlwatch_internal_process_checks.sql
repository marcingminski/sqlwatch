CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_checks] 
AS
/*
-------------------------------------------------------------------------------------------------------------------
 usp_sqlwatch_internal_process_alerts

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/

set nocount on;
set xact_abort on;

declare @check_name nvarchar(100),
		@check_description nvarchar(2048),
		@check_query nvarchar(max),
		@check_warning_threshold varchar(100),
		@check_critical_threshold varchar(100),
		@check_query_instance varchar(32),
		@check_id smallint,
		@check_start_time datetime2(7),
		@check_exec_time_ms real,
		@actions xml

declare @check_status varchar(50),
		@check_value decimal(28,2),
		@last_check_status varchar(50),
		@previous_value decimal(28,2),
		@last_status_change datetime,
		@retrigger_time smallint,
		@last_trigger_time datetime,
		@trigger_date datetime,
		@send_recovery bit,
		@send_email bit = 1,
		@retrigger_on_every_change bit,
		@target_type varchar(50),
		@error_message nvarchar(max) = '',
		@trigger_limit_hour tinyint, --max number of messages per hour
		@trigger_current_count smallint

declare @email_subject nvarchar(255),
		@email_body nvarchar(4000),
		@target_attributes nvarchar(255),
		@recipients nvarchar(255),
		@msg_payload nvarchar(max)

declare @action_id smallint,
		@subject nvarchar(max),
		@body nvarchar(max),
		@previous_check_date datetime, 
		@previous_check_value real, 
		@previous_check_status varchar(50)

declare @snapshot_type_id tinyint = 18,
		@snapshot_date datetime2(0) = getutcdate()

declare @mail_return_code int

declare @check_output as table (
	value decimal(28,2) not null
	)

insert into [dbo].[sqlwatch_logger_snapshot_header]
values (@snapshot_date, @snapshot_type_id, @@SERVERNAME)

insert into [dbo].[sqlwatch_meta_check]([sql_instance],[check_id])
select s.[sql_instance], s.[check_id]
from [dbo].[sqlwatch_config_check] s
left join [dbo].[sqlwatch_meta_check] t
on s.sql_instance = t.sql_instance
and s.check_id = t.check_id
where t.check_id is null

declare cur_rules cursor for

select 
	  cc.[check_id]
	, cc.[check_name]
	, cc.[check_description]
	, cc.[check_query]
	, cc.[check_threshold_warning]
	, cc.[check_threshold_critical]
	, last_check_date = isnull(mc.last_check_date,'1970-01-01')
	, mc.last_check_value
	, mc.last_check_status
from [dbo].[sqlwatch_config_check] cc

inner join [dbo].[sqlwatch_meta_check] mc
	on mc.sql_instance = cc.sql_instance
	and mc.check_id = cc.check_id

where [check_enabled] = 1
and datediff(minute,isnull(mc.last_check_date,'1970-01-01'),getdate()) >= isnull([check_frequency_minutes],0)
and cc.sql_instance = @@SERVERNAME
order by cc.[check_id]

open cur_rules   
  
fetch next from cur_rules 
into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold, @previous_check_date, @previous_check_value, @previous_check_status

  while @@FETCH_STATUS = 0  
begin
	

	set @check_status = null
	set @check_value = null
	set @actions = null
	delete from @check_output



	-------------------------------------------------------------------------------------------------------------------
	-- execute check and log output in variable:
	-------------------------------------------------------------------------------------------------------------------
	set @check_start_time = SYSDATETIME()

	begin try
		insert into @check_output ([value])
		exec sp_executesql @check_query
	end try
	begin catch
		select @error_message = @error_message + '
' + convert(varchar(23),getdate(),121) + ': CheckID: ' + convert(varchar(10),@check_id) + ': ' + ERROR_MESSAGE()

		update	[dbo].[sqlwatch_meta_check]
		set last_check_date = getdate(),
			last_check_status = 'CHECK ERROR'
		where [check_id] = @check_id
		and sql_instance = @@SERVERNAME

		goto ProcessNextCheck
	end catch

	set @check_exec_time_ms = convert(real,datediff(MICROSECOND,@check_start_time,SYSDATETIME()) / 1000.0 )

	select @check_value = [value] from @check_output
	--although we have already capturing errors let's double check that the value is in fact not null

	if @check_value is null
		goto ProcessNextCheck

	-- override send_email flag based on the trigger (message) limit per hour:
	--set @send_email = case when @send_email = 1 and isnull(@trigger_current_count,0) <= @trigger_limit_hour then 1 else 0 end

	-------------------------------------------------------------------------------------------------------------------
	-- set check status based on the output:
	-- there are 3 basic options: OK, WARNING and CRITICAL.
	-- the critical could be greater or lower, or just different than the success for example:
	--	1. we can have an alert to trigger if someone drops database. in that case the critical would be less than desired value
	--	2. we can have a trigger if someone creates new databsae in which case, the critical would be greater than desired value
	--	3. we can have a trigger that checks for a number of databases and any change is critical either greater or lower.
	-------------------------------------------------------------------------------------------------------------------

	--get last check value for substition:
	--select @previous_check_value = [last_check_value]
	--from [dbo].[sqlwatch_meta_check]
	--where check_id = @check_id

	--we can also pass variables into the tresholds. for example we may only want to be notified if number of failed agent jobs increaeses.
	--if @previous_check_value is not null
	--	begin
	--		set @check_critical_threshold = replace(@check_critical_threshold,'{LAST_CHECK_VALUE}',convert(varchar(100),@previous_check_value))
	--		set @check_warning_threshold  = replace(@check_warning_threshold,'{LAST_CHECK_VALUE}',convert(varchar(100),@previous_check_value))
	--	end

	--we must either have critical value or warning and critical. constraints dissalow the critical warning to be null and previous check ensured check_value is not null:
	select @check_status = case when [dbo].[ufn_sqlwatch_get_check_status] ( @check_critical_threshold, @check_value ) = 1 then 'CRITICAL' end

	--if @check_status is still null then check if its warning, but we may not have warning so need to account for that:
	select @check_status = case when @check_status is null and @check_warning_threshold is not null and [dbo].[ufn_sqlwatch_get_check_status] ( @check_warning_threshold, @check_value ) = 1 then 'WARNING' else @check_status end

	--if not warninig or critical then OK
	if @check_status is null
		set @check_status = 'OK'

	-------------------------------------------------------------------------------------------------------------------
	-- log check results:
	-------------------------------------------------------------------------------------------------------------------
	insert into [dbo].[sqlwatch_logger_check] (sql_instance, snapshot_time, snapshot_type_id, check_id, 
		[check_value], [check_status], check_exec_time_ms)
	values (@@SERVERNAME, @snapshot_date, @snapshot_type_id, @check_id, @check_value, @check_status, @check_exec_time_ms)

	-------------------------------------------------------------------------------------------------------------------
	-- process any actions for this check:
	-------------------------------------------------------------------------------------------------------------------
	declare cur_actions cursor for
	select [action_id]
		from [dbo].[sqlwatch_config_check_action]
		where check_id = @check_id
		and sql_instance = @@SERVERNAME
		order by check_id

		open cur_actions
  
		fetch next from cur_actions 
		into @action_id

		while @@FETCH_STATUS = 0  
			begin
				begin try
					exec [dbo].[usp_sqlwatch_internal_process_actions] 
						@sql_instance = @@SERVERNAME,
						@check_id = @check_id,
						@action_id = @action_id,
						@check_status = @check_status,
						@check_value = @check_value,
						@check_snapshot_time = @snapshot_date
				end try
				begin catch
						select @error_message = @error_message + '
' + convert(varchar(23),getdate(),121) + ': CheckID: ' + convert(varchar(10),@check_id) + ': ActionID: ' + convert(varchar(10),@action_id) + ' ' + ERROR_MESSAGE()

					goto NextAction
				end catch

				NextAction:
				fetch next from cur_actions 
				into @action_id
			end

	close cur_actions
	deallocate cur_actions
	-------------------------------------------------------------------------------------------------------------------
	-- update meta with the latest values.
	-- we have to do this after we have triggered actions as the [usp_sqlwatch_internal_process_actions] needs
	-- previous values
	-------------------------------------------------------------------------------------------------------------------
	update	[dbo].[sqlwatch_meta_check]
	set last_check_date = getdate(),
		last_check_value = @check_value,
		last_check_status = @check_status,
		last_status_change_date = case when @previous_check_status <> @check_status then getdate() else last_status_change_date end
	where [check_id] = @check_id
	and sql_instance = @@SERVERNAME

	ProcessNextCheck:

	fetch next from cur_rules 
	into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold, @previous_check_date, @previous_check_value, @previous_check_status
	
end

close cur_rules
deallocate cur_rules


if nullif(@error_message,'') is not null
	begin
		set @error_message = 'Errors during check execution: 
' + @error_message

		raiserror (@error_message,16,1)
	end

--	-------------------------------------------------------------------------------------------------------------------
--	-- BUILD PAYLOAD
--	-------------------------------------------------------------------------------------------------------------------
--	if @send_email = 1
--		begin
--			-------------------------------------------------------------------------------------------------------------------
--			-- now set the email subject and appropriate flags to indicate what is happening.
--			-- optons are below:
--			-------------------------------------------------------------------------------------------------------------------

--			-------------------------------------------------------------------------------------------------------------------
--			-- if previous status is NOT ok and current status is OK the check has recovered from fail to success.
--			-- we can send an email notyfing DBAs that the problem has gone away
--			-------------------------------------------------------------------------------------------------------------------
--			if @last_check_status <> '' and @last_check_status <> 'OK' and @check_status = 'OK'
--				begin
--					Print @last_check_status
--					set @send_email = @send_recovery
--					set @email_subject = 'RECOVERED (OK): ' + @check_name + ' on ' + @check_query_instance 
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- retrigger if the value has changed, regardless of the status.
--			-- this is handy if we want to monitor every change after it has failed. for example we can set to monitor
--			-- if number of logins is greater than 5 so if someone creates a new login we will get an email and then every time
--			-- new login is created
--			-------------------------------------------------------------------------------------------------------------------
--			else if @check_status <> 'OK' and @retrigger_on_every_change = 1 and @check_value <> @previous_value
--				begin
--					set @email_subject = @check_name + ': ' + @check_status + ' on ' + @check_query_instance
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- when the current status is not OK and the previous status has changed, it is a new notification:
--			-------------------------------------------------------------------------------------------------------------------
--			else if @check_status <> 'OK' and @last_check_status <> @check_status
--				begin
--					set @email_subject = @check_name + ': ' + @check_status + ' on ' + @check_query_instance
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- if the previous status is the same as the current status we would not normally send another email
--			-- however, we can do if we set retrigger time. for example, we can be sending repeated alerts every hour so 
--			-- they do not get forgotten about. 
--			-------------------------------------------------------------------------------------------------------------------
--			else if @check_status <> 'OK' and @last_check_status = @check_status and (@retrigger_time is not null and datediff(minute,@last_trigger_time,getdate()) > @retrigger_time)
--				begin
--					set @email_subject = 'REPEATED : ' + @check_status + ' ' + @check_name + ' on ' + @check_query_instance 
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- if the previous status is null and current status is OK it probably a new check and we are not doing anything.
--			-------------------------------------------------------------------------------------------------------------------
--			else if @check_status = 'OK' and  @last_check_status = ''
--				begin
--					set @send_email = 0
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- if the previous status is the same as current status and no retrigger defined we are not doing anything.
--			-------------------------------------------------------------------------------------------------------------------
--			else if @last_check_status <> '' and @last_check_status = @check_status and (@retrigger_time is null or datediff(minute,@last_trigger_time,getdate()) < @retrigger_time)
--				begin
--					--print 'Check id: ' + convert(varchar(10),@check_id) + ': no action'
--					set @send_email = 0
--				end
--			else
--				begin
--					--print 'Check id: ' + convert(varchar(10),@check_id) + ': UNDEFINED'
--					set @send_email = 0
--				end

--			-------------------------------------------------------------------------------------------------------------------
--			-- set email content
--			-------------------------------------------------------------------------------------------------------------------
--			if @send_email = 0
--				goto SkipEmail

--			set @email_body = '
--Check: ' + @check_name + ' (CheckId:' + convert(varchar(50),@check_id) + ')

--Current status: ' + @check_status + '
--Current value: ' + convert(varchar(100),@check_value) + '

--Previous value: ' + convert(varchar(100),@previous_value) + '
--Previous status: ' + @last_check_status + '
--Previous change: ' + convert(varchar(23),@last_status_change,121) + '

--SQL instance: ' + @check_query_instance + '
--Alert time: ' + convert(varchar(23),getdate(),121) + '

--Warning threshold: ' + isnull(convert(varchar(100),@check_warning_threshold),'NULL') + '
--Critical threshold: ' + isnull(convert(varchar(100),@check_critical_threshold),'NULL') + '
--Retrigger time: ' + convert(varchar(50),case 
--	when @retrigger_time is null then 'With every check'
--	when @retrigger_time = 1 then 'Every 1 minute'
--	when @retrigger_time > 1 then 'Every ' + convert(varchar(10),@retrigger_time) + ' minutes'
--	else '' end) + '
--Trigger rule: ' + case when @retrigger_on_every_change = 1 then 'On every value change' else ' Trigger once per status change' end + '
	
----- Check Description:

--' + @check_description + '

----- Check Query:

--' + @check_query + '

-----


--Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
--https://docs.sqlwatch.io '


--			if @email_subject is not null and @email_body is not null and @recipients is not null
--				begin
--					set @msg_payload = [dbo].[ufn_sqlwatch_get_delivery_command] (@recipients, @email_subject, @email_body, @target_attributes, @target_type)
--					-------------------------------------------------------------------------------------------------------------------
--					-- insert into message queue table:
--					-------------------------------------------------------------------------------------------------------------------
--					insert into [dbo].[sqlwatch_meta_delivery_queue]([sql_instance], [time_queued], [delivery_target_type], [delivery_command], [delivery_status])
--					values (@@SERVERNAME, sysdatetime(), @target_type, @msg_payload, 0)
--				end
--		end

--	-------------------------------------------------------------------------------------------------------------------
--	-- log alert in logger table and move on to the next item

--	-- at this point, the @send_email flag is an indication whether the notification has been requested or not and  NOT
--	-- whether it was successfuly delivered. delivery happens in another step and currently there is no feedback.
--	-- However, if the notification fails and we get hold of the status code, we will keep failed notifications in the queue table.
--	-------------------------------------------------------------------------------------------------------------------
--	SkipEmail:

