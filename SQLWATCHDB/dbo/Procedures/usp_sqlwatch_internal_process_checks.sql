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

declare @header nvarchar(100),
		@description nvarchar(2048),
		@sql nvarchar(max),
		@success varchar(100),
		@warning varchar(100),
		@critical varchar(100),
		@sql_instance varchar(32),
		@rule_id smallint,
		@check_start_time datetime2(7),
		@check_exec_time_ms real

declare @check_status varchar(50),
		@check_output_value decimal(28,2),
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

declare @snapshot_type_id tinyint = 18,
		@snapshot_date datetime2(0) = getutcdate()

declare @mail_return_code int

declare @check_output as table (
	value decimal(28,2) not null
	)

insert into [dbo].[sqlwatch_logger_snapshot_header]
values (@snapshot_date, @snapshot_type_id, @@SERVERNAME)

insert into [dbo].[sqlwatch_meta_alert]([sql_instance],[check_id])
select s.[sql_instance], s.[check_id]
from [dbo].[sqlwatch_config_alert_check] s
left join [dbo].[sqlwatch_meta_alert] t
on s.sql_instance = t.sql_instance
and s.check_id = t.check_id
where t.check_id is null

declare cur_rules cursor for
select	  ac.[check_id]
		, ac.[check_name]
		, ac.[check_description]
		, ac.[check_query]
		, ac.[check_threshold_warning]
		, ac.[check_threshold_critical]
		, ac.[sql_instance]
		, isnull(last_check_status,'')
		, t.[delivery_target_address]
		, t.[delivery_target_attributes]
		, [last_check_value]
		, isnull([last_status_change_date],'1970-01-01')
		, [delivery_repeat_period_minutes]
		, isnull(last_notification_sent,'1970-01-01')
		, [deliver_recovery]
		, [deliver_every_failure]
		, ac.[delivery_enabled]
		, [delivery_target_type]
		, [max_deliveries_per_hour]
		, [last_hour_trigger_count] = total_notifications_in_last_hour
from [dbo].[sqlwatch_config_alert_check] ac

	left join [dbo].[vw_sqlwatch_report_dim_alert] ma
	on ac.sql_instance = ma.sql_instance
	and ac.check_id = ma.check_id

	left join [dbo].[sqlwatch_config_delivery_target] t
		on t.[delivery_target_id] = ac.[delivery_target_id]

where [check_enabled] = 1
and datediff(minute,isnull([last_check_date],'1970-01-01'),getdate()) >= isnull([check_frequency_minutes],0)

open cur_rules   
  
fetch next from cur_rules 
into @rule_id, @header, @description , @sql, @warning, @critical, @sql_instance, @last_check_status, @recipients, @target_attributes, @previous_value, @last_status_change, @retrigger_time
	, @last_trigger_time, @send_recovery, @retrigger_on_every_change, @send_email, @target_type, @trigger_limit_hour, @trigger_current_count
  
while @@FETCH_STATUS = 0  
begin
	

	set @check_status = null
	set @check_output_value = null
	delete from @check_output

	-- override send_email flag based on the trigger (message) limit per hour:
	set @send_email = case when @send_email = 1 and isnull(@trigger_current_count,0) <= @trigger_limit_hour then 1 else 0 end

	-------------------------------------------------------------------------------------------------------------------
	-- execute check and log output in variable:
	-------------------------------------------------------------------------------------------------------------------
	set @check_start_time = SYSDATETIME()

	begin try
		insert into @check_output ([value])
		exec sp_executesql @sql
	end try
	begin catch
		select @error_message = @error_message + '
' + convert(varchar(23),getdate(),121) + ': CheckID: ' + convert(varchar(10),@rule_id) + ': ' + ERROR_MESSAGE()

		update	[dbo].[sqlwatch_meta_alert]
		set last_check_date = getdate(),
			last_check_status = 'CHECK ERROR'
		where [check_id] = @rule_id
		and sql_instance = @@SERVERNAME

		goto ProcessNextCheck
	end catch

	set @check_exec_time_ms = convert(real,datediff(MICROSECOND,@check_start_time,SYSDATETIME()) * 1000.0)

	select @check_output_value = [value] from @check_output

	-------------------------------------------------------------------------------------------------------------------
	-- set check status based on the output:
	-- there are 3 basic options: OK, WARNING and CRITICAL.
	-- the critical could be greater or lower, or just different than the success for example:
	--	1. we can have an alert to trigger if someone drops database. in that case the critical would be less than desired value
	--	2. we can have a trigger if someone creates new databsae in which case, the critical would be greater than desired value
	--	3. we can have a trigger that checks for a number of databases and any change is critical either greater or lower.
	-------------------------------------------------------------------------------------------------------------------

--if @critical is not null and @check_status is null


select @check_status = case when @critical is not null and @check_status is null and [dbo].[ufn_sqlwatch_get_check_status] ( @critical, @check_output_value ) = 1 then 'CRITICAL' end
select @check_status = case when @warning is not null and @check_status is null and [dbo].[ufn_sqlwatch_get_check_status] ( @critical, @check_output_value ) = 1 then 'WARNING' end


--if @warning is not null and @check_status is null
--	begin
--		select @check_status = case when [dbo].[ufn_sqlwatch_get_check_status] ( @critical, @check_output_value ) = 1 then 'CRITICAL' end
--	end
	--begin
	--	if left(@critical,2) = '<=' 
	--		begin
	--			if @check_output_value <= convert(decimal(28,2),replace(@critical,'<=',''))
	--				set @check_status = 'CRITICAL'
	--		end
	--	else if left(@critical,2) = '>='
	--		begin
	--			if @check_output_value >= convert(decimal(28,2),replace(@critical,'>=','')) 
	--				set @check_status = 'CRITICAL'
	--		end
	--	else if left(@critical,2) = '<>'
	--		begin
	--			if @check_output_value <> convert(decimal(28,2),replace(@critical,'<>','')) 
	--				set @check_status = 'CRITICAL'
	--		end

	--	else if left(@critical,1) = '>'
	--		begin
	--			if @check_output_value > convert(decimal(28,2),replace(@critical,'>','')) 
	--				set @check_status = 'CRITICAL'
	--		end
	--	else if left(@critical,1) = '<'
	--		begin
	--			if @check_output_value < convert(decimal(28,2),replace(@critical,'<','')) 
	--				set @check_status = 'CRITICAL'
	--		end
	--	else if left(@critical,1) = '='
	--		begin
	--			if @check_output_value = convert(decimal(28,2),replace(@critical,'=','')) 
	--				set @check_status = 'CRITICAL'
	--		end
	--	else
	--		begin
	--			if @check_output_value = convert(decimal(28,2),@critical) 
	--				set @check_status = 'CRITICAL'
	--		end
	--end

--if @warning is not null and @check_status is null
--	begin
--		if left(@warning,2) = '<=' 
--			begin
--				if @check_output_value <= convert(decimal(28,2),replace(@warning,'<=',''))
--					set @check_status = 'WARNING'
--			end
--		else if left(@warning,2) = '>='
--			begin
--				if @check_output_value >= convert(decimal(28,2),replace(@warning,'>=','')) 
--					set @check_status = 'WARNING'
--			end
--		else if left(@warning,2) = '<>'
--			begin
--				if @check_output_value <> convert(decimal(28,2),replace(@warning,'<>','')) 
--					set @check_status = 'WARNING'
--			end

--		else if left(@warning,1) = '>'
--			begin
--				if @check_output_value > convert(decimal(28,2),replace(@warning,'>','')) 
--					set @check_status = 'WARNING'
--			end
--		else if left(@warning,1) = '<'
--			begin
--				if @check_output_value < convert(decimal(28,2),replace(@warning,'<','')) 
--					set @check_status = 'WARNING'
--			end
--		else if left(@warning,1) = '='
--			begin
--				if @check_output_value = convert(decimal(28,2),replace(@warning,'=','')) 
--					set @check_status = 'WARNING'
--			end
--		else
--			begin
--				if @check_output_value = convert(decimal(28,2),@warning) 
--					set @check_status = 'WARNING'
--			end
--	end

--if @success is null and @check_status is still null after having evaluated all conditions we are assuming OK status
--it will likely mean that it is not critical, nor warning so must be ok
if @check_status is null and @success is null
 set @check_status = 'OK'

--if we are still getting NULL then is must be an exception:
if @check_status is null and @critical is null
 set @check_status = 'UNKNOWN'

	-------------------------------------------------------------------------------------------------------------------
	-- update meta with the latest values
	-------------------------------------------------------------------------------------------------------------------
	update	[dbo].[sqlwatch_meta_alert]
	set last_check_date = getdate(),
		last_check_value = @check_output_value,
		last_check_status = @check_status,
		last_status_change_date = case when @last_check_status <> @check_status then getdate() else last_status_change_date end
	where [check_id] = @rule_id
	and sql_instance = @@SERVERNAME

	-------------------------------------------------------------------------------------------------------------------
	-- BUILD PAYLOAD
	-------------------------------------------------------------------------------------------------------------------
	if @send_email = 1
		begin
			-------------------------------------------------------------------------------------------------------------------
			-- now set the email subject and appropriate flags to indicate what is happening.
			-- optons are below:
			-------------------------------------------------------------------------------------------------------------------

			-------------------------------------------------------------------------------------------------------------------
			-- if previous status is NOT ok and current status is OK the check has recovered from fail to success.
			-- we can send an email notyfing DBAs that the problem has gone away
			-------------------------------------------------------------------------------------------------------------------
			if @last_check_status <> '' and @last_check_status <> 'OK' and @check_status = 'OK'
				begin
					Print @last_check_status
					set @send_email = @send_recovery
					set @email_subject = 'RECOVERED (OK): ' + @header + ' on ' + @sql_instance 
				end

			-------------------------------------------------------------------------------------------------------------------
			-- retrigger if the value has changed, regardless of the status.
			-- this is handy if we want to monitor every change after it has failed. for example we can set to monitor
			-- if number of logins is greater than 5 so if someone creates a new login we will get an email and then every time
			-- new login is created
			-------------------------------------------------------------------------------------------------------------------
			else if @check_status <> 'OK' and @retrigger_on_every_change = 1 and @check_output_value <> @previous_value
				begin
					set @email_subject = @header + ': ' + @check_status + ' on ' + @sql_instance
				end

			-------------------------------------------------------------------------------------------------------------------
			-- when the current status is not OK and the previous status has changed, it is a new notification:
			-------------------------------------------------------------------------------------------------------------------
			else if @check_status <> 'OK' and @last_check_status <> @check_status
				begin
					set @email_subject = @header + ': ' + @check_status + ' on ' + @sql_instance
				end

			-------------------------------------------------------------------------------------------------------------------
			-- if the previous status is the same as the current status we would not normally send another email
			-- however, we can do if we set retrigger time. for example, we can be sending repeated alerts every hour so 
			-- they do not get forgotten about. 
			-------------------------------------------------------------------------------------------------------------------
			else if @check_status <> 'OK' and @last_check_status = @check_status and (@retrigger_time is not null and datediff(minute,@last_trigger_time,getdate()) > @retrigger_time)
				begin
					set @email_subject = 'REPEATED : ' + @check_status + ' ' + @header + ' on ' + @sql_instance 
				end

			-------------------------------------------------------------------------------------------------------------------
			-- if the previous status is null and current status is OK it probably a new check and we are not doing anything.
			-------------------------------------------------------------------------------------------------------------------
			else if @check_status = 'OK' and  @last_check_status = ''
				begin
					set @send_email = 0
				end

			-------------------------------------------------------------------------------------------------------------------
			-- if the previous status is the same as current status and no retrigger defined we are not doing anything.
			-------------------------------------------------------------------------------------------------------------------
			else if @last_check_status <> '' and @last_check_status = @check_status and (@retrigger_time is null or datediff(minute,@last_trigger_time,getdate()) < @retrigger_time)
				begin
					--print 'Check id: ' + convert(varchar(10),@rule_id) + ': no action'
					set @send_email = 0
				end
			else
				begin
					--print 'Check id: ' + convert(varchar(10),@rule_id) + ': UNDEFINED'
					set @send_email = 0
				end

			-------------------------------------------------------------------------------------------------------------------
			-- set email content
			-------------------------------------------------------------------------------------------------------------------
			if @send_email = 0
				goto SkipEmail

			set @email_body = '
Check: ' + @header + ' (CheckId:' + convert(varchar(50),@rule_id) + ')

Current status: ' + @check_status + '
Current value: ' + convert(varchar(100),@check_output_value) + '

Previous value: ' + convert(varchar(100),@previous_value) + '
Previous status: ' + @last_check_status + '
Previous change: ' + convert(varchar(23),@last_status_change,121) + '

SQL instance: ' + @sql_instance + '
Alert time: ' + convert(varchar(23),getdate(),121) + '

Warning threshold: ' + isnull(convert(varchar(100),@warning),'NULL') + '
Critical threshold: ' + isnull(convert(varchar(100),@critical),'NULL') + '
Retrigger time: ' + convert(varchar(50),case 
	when @retrigger_time is null then 'With every check'
	when @retrigger_time = 1 then 'Every 1 minute'
	when @retrigger_time > 1 then 'Every ' + convert(varchar(10),@retrigger_time) + ' minutes'
	else '' end) + '
Trigger rule: ' + case when @retrigger_on_every_change = 1 then 'On every value change' else ' Trigger once per status change' end + '
	
--- Check Description:

' + @description + '

--- Check Query:

' + @sql + '

---


Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
https://docs.sqlwatch.io '


			if @email_subject is not null and @email_body is not null and @recipients is not null
				begin
					set @msg_payload = [dbo].[ufn_sqlwatch_get_delivery_command] (@recipients, @email_subject, @email_body, @target_attributes, @target_type)
					-------------------------------------------------------------------------------------------------------------------
					-- insert into message queue table:
					-------------------------------------------------------------------------------------------------------------------
					insert into [dbo].[sqlwatch_meta_delivery_queue]([sql_instance], [time_queued], [check_id], [delivery_target_type], [delivery_command], [delivery_status])
					values (@@SERVERNAME, sysdatetime(), @rule_id, @target_type, @msg_payload, 0)
				end
		end

	-------------------------------------------------------------------------------------------------------------------
	-- log alert in logger table and move on to the next item

	-- at this point, the @send_email flag is an indication whether the notification has been requested or not and  NOT
	-- whether it was successfuly delivered. delivery happens in another step and currently there is no feedback.
	-- However, if the notification fails and we get hold of the status code, we will keep failed notifications in the queue table.
	-------------------------------------------------------------------------------------------------------------------
	SkipEmail:

	insert into [dbo].[sqlwatch_logger_alert_check] (sql_instance, snapshot_time, snapshot_type_id, check_id, 
		check_result, check_pass, delivery_trigger, check_exec_time_ms)
	values (@@SERVERNAME, @snapshot_date, @snapshot_type_id, @rule_id, @check_output_value, case when @check_status = 'OK' then 1 else 0 end, @send_email, @check_exec_time_ms)

	ProcessNextCheck:

	fetch next from cur_rules 
	into @rule_id, @header, @description , @sql, @warning, @critical, @sql_instance, @last_check_status, @recipients, @target_attributes, @previous_value, @last_status_change, @retrigger_time
		, @last_trigger_time, @send_recovery, @retrigger_on_every_change, @send_email, @target_type, @trigger_limit_hour, @trigger_current_count
	
end

close cur_rules
deallocate cur_rules


if nullif(@error_message,'') is not null
	begin
		set @error_message = 'Errors during check execution: 
' + @error_message

		raiserror (@error_message,16,1)
	end