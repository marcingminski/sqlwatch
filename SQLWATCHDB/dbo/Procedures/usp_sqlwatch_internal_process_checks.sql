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
	on mc.check_id = cc.check_id
	and mc.sql_instance = @@SERVERNAME

where [check_enabled] = 1
and datediff(minute,isnull(mc.last_check_date,'1970-01-01'),getdate()) >= isnull(mc.[check_frequency_minutes],0)
--and cc.sql_instance = @@SERVERNAME
order by cc.[check_id]

open cur_rules   
  
fetch next from cur_rules 
into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold
	, @previous_check_date, @previous_check_value, @previous_check_status


while @@FETCH_STATUS = 0  
begin
	

	set @check_status = null
	set @check_value = null
	set @actions = null
	delete from @check_output

	Print 'Check (Id: ' + convert(varchar(10),@check_id) + ')'

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
	-- process any actions for this check but only if status not OK or previous status was not OK (so we can process recovery)
	-- if current and previous status was OK we wouldnt have any actions anyway so there is no point calling the proc.
	-- assuming 99% of time all checks will come back as OK, this will save significant CPU time
	-------------------------------------------------------------------------------------------------------------------
	if @check_status <> 'OK' or @last_check_status <> 'OK'
		begin
			declare cur_actions cursor for
			select cca.[action_id]
				from [dbo].[sqlwatch_config_check_action] cca
					--so we only try process actions that are enabled:
					inner join [dbo].[sqlwatch_config_action] ca
						on cca.action_id = ca.action_id
				where cca.check_id = @check_id
				and ca.action_enabled = 1
				order by cca.check_id

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
								@check_snapshot_time = @snapshot_date,
								@check_description = @check_description,
								@check_name = @check_name
						end try
						begin catch
							select @error_message = @error_message + '
		' + convert(varchar(23),getdate(),121) + ': CheckID: ' + convert(varchar(10),@check_id) + ': ActionID: ' + convert(varchar(10),@action_id) + '
			 ERROR_NUMBER: ' + convert(varchar(10),ERROR_NUMBER()) + '
             ERROR_SEVERITY : ' + convert(varchar(max),ERROR_SEVERITY()) + '
             ERROR_STATE : ' + convert(varchar(max),ERROR_STATE()) + '   
             ERROR_PROCEDURE : ' + convert(varchar(max),ERROR_PROCEDURE()) + '   
             ERROR_LINE : ' + convert(varchar(max),ERROR_LINE()) + '   
             ERROR_MESSAGE : ' + convert(varchar(max),ERROR_MESSAGE()) + ''
						
							--immediate feedback without terminating the batch and continue processing remaining checks:
							--raiserror ('%s',1, 1, @error_message)
						end catch

						NextAction:
						fetch next from cur_actions 
						into @action_id
					end

			close cur_actions
			deallocate cur_actions
		end
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
	into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold
		, @previous_check_date, @previous_check_value, @previous_check_status
	
end

close cur_rules
deallocate cur_rules

Print 'No Checks to Process'


if nullif(@error_message,'') is not null
	begin
		set @error_message = 'Errors during check execution: 
' + @error_message

		--print all errors and terminate the batch which will also fail the agent job for the attention:
		raiserror ('%s',16,1,@error_message)
	end