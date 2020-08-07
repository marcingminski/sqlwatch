CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_checks] 
AS
/*
-------------------------------------------------------------------------------------------------------------------
 usp_sqlwatch_internal_process_alerts

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/

SET NOCOUNT ON 
SET DATEFORMAT ymd --fix for non EN formats

declare @check_name nvarchar(100),
		@check_description nvarchar(2048),
		@check_query nvarchar(max),
		@check_warning_threshold varchar(100),
		@check_critical_threshold varchar(100),
		@check_query_instance varchar(32),
		@check_id smallint,
		@check_start_time datetime2(7),
		@check_end_time datetime2(7),
		@check_exec_time_ms real,
		@actions xml

declare @check_status varchar(50),
		@check_value decimal(28,5),
		@last_check_status varchar(50),
		@previous_value decimal(28,5),
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
		@trigger_current_count smallint,
		@error_message_single nvarchar(max) = '',
		@error_message_xml xml,
		@has_errors bit = 0

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
		@previous_check_status varchar(50),
		@check_time datetime,
		@ignore_flapping bit,
		@is_flapping bit


declare @snapshot_type_id tinyint = 18,
		@snapshot_type_id_action tinyint = 19,
		@snapshot_time datetime2(0) = getutcdate(),
		@snapshot_time_action datetime2(0)

declare @mail_return_code int

exec [dbo].[usp_sqlwatch_internal_insert_header] 
	@snapshot_time_new = @snapshot_time OUTPUT,
	@snapshot_type_id = @snapshot_type_id

declare cur_rules cursor LOCAL FAST_FORWARD for
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
	, cc.[ignore_flapping]
from [dbo].[sqlwatch_config_check] cc

inner join [dbo].[sqlwatch_meta_check] mc
	on mc.check_id = cc.check_id
	and mc.sql_instance = @@SERVERNAME

where [check_enabled] = 1
and datediff(minute,isnull(mc.last_check_date,'1970-01-01'),getutcdate()) >= isnull(mc.[check_frequency_minutes],0)
order by cc.[check_id]

open cur_rules   
  
fetch next from cur_rules 
into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold
	, @previous_check_date, @previous_check_value, @previous_check_status, @ignore_flapping


while @@FETCH_STATUS = 0  
begin
	
	set @check_status = null
	set @check_value = null
	set @actions = null
	set @error_message = ''
	set @is_flapping = 0

	-------------------------------------------------------------------------------------------------------------------
	-- execute check and log output in variable:
	-- APP_STAGE: 5980A79A-D6BC-4BA0-8B86-A388E8DB621D
	-------------------------------------------------------------------------------------------------------------------
	set @check_start_time = SYSUTCDATETIME()

	begin try
		set @check_query = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON 
SET ANSI_WARNINGS OFF
' + replace(@check_query,'{LAST_CHECK_DATE}',convert(varchar(23),@previous_check_date,121))
		exec sp_executesql @check_query, N'@output decimal(28,5) OUTPUT', @output = @check_value output;
		set @check_end_time = SYSUTCDATETIME()
		set @check_exec_time_ms = convert(real,datediff(MICROSECOND,@check_start_time,@check_end_time) / 1000.0 )
		if @check_value is null
			begin
				set @error_message = 'Unable to evaluate thresholds because Check (Id: ' + convert(varchar(10),@check_id) + ') has returned NULL value'
				raiserror (@error_message, 16, 1)
			end
	end try
	begin catch

		if @error_message is null or @error_message = '' 
			begin 
				set @error_message = replace(@check_query,'%','%%')
			end
		else
			begin
				set @error_message = @error_message + '
--- Query -------------------------------------------------
' + replace(@check_query,'%','%%') + ''
			end

		if dbo.ufn_sqlwatch_get_config_value(8, null) <> 0
			begin
				set @has_errors = 1

				select FAILED_QUERY = @check_query, ERROR_MESSAGE = ERROR_MESSAGE()				

				exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = '5980A79A-D6BC-4BA0-8B86-A388E8DB621D',
					@process_message = @error_message,
					@process_message_type = 'ERROR'
			end
		else
			begin
				exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = 'ED7B7EC1-6F0A-4B23-909E-7BB1D37B300D',
					@process_message = @error_message,
					@process_message_type = 'WARNING'
			end


		update	[dbo].[sqlwatch_meta_check]
		set last_check_date = isnull(@check_end_time,SYSUTCDATETIME()),
			last_check_status = 'CHECK ERROR'
		where [check_id] = @check_id
		and sql_instance = @@SERVERNAME

		set @error_message = 'CheckID : ' + convert(varchar(10),@check_id)
						
		insert into [dbo].[sqlwatch_logger_check] (sql_instance, snapshot_time, snapshot_type_id, check_id, 
			[check_value], [check_status], check_exec_time_ms)
		values (@@SERVERNAME, @snapshot_time, @snapshot_type_id, @check_id, null, 'CHECK ERROR', @check_exec_time_ms)
			
		goto ProcessNextCheck
	end catch


	-------------------------------------------------------------------------------------------------------------------
	--	Check for flapping
	--  needs some work to be more reliable
	--  we take last 12 checks (based on 5 minute check = 60 minutes)
	--  and calculate change ratio. result 0.5 will mean exact number of failures and OK which means flapping.
	--  to give it some leaway, we say ignore if betwen 0.35 and 0.65.
	--	this approach is far from ideal but will do for now. if causing trouble it can be disabled in config_check
	-------------------------------------------------------------------------------------------------------------------
	if @ignore_flapping = 0 and (
						select avg(convert(decimal(10,2),status_change))
							from (
								select top 12 *
								from dbo.[sqlwatch_logger_check] lc
								where snapshot_time > dateadd(hour,-6,getutcdate())
								and sql_instance = @@SERVERNAME
								and check_id = @check_id
								and snapshot_type_id = @snapshot_type_id
								order by snapshot_time desc
							) t
						) between 0.35 and 0.65
		begin
			set @is_flapping = 1
			--warning only:
			set @error_message = 'Check (Id: ' + convert(varchar(10),@check_id) + ') is flapping.'
			exec [dbo].[usp_sqlwatch_internal_log]
					@proc_id = @@PROCID,
					@process_stage = '040D0A86-83B8-4543-A34C-9F328DAE5488',
					@process_message = @error_message,
					@process_message_type = 'WARNING'
		end

	-------------------------------------------------------------------------------------------------------------------
	-- set check status based on the output:
	-- there are 3 basic options: OK, WARNING and CRITICAL.
	-- the critical could be greater or lower, or just different than the success for example:
	--	1. we can have an alert to trigger if someone drops database. in that case the critical would be less than desired value
	--	2. we can have a trigger if someone creates new databsae in which case, the critical would be greater than desired value
	--	3. we can have a trigger that checks for a number of databases and any change is critical either greater or lower.
	-------------------------------------------------------------------------------------------------------------------

	--we must either have critical value or warning and critical. constraints dissalow the critical warning to be null and previous check ensured check_value is not null:
	select @check_status = case 
		when [dbo].[ufn_sqlwatch_get_check_status] ( @check_critical_threshold, @check_value ) = 1 then 'CRITICAL'
		when @check_warning_threshold is not null and [dbo].[ufn_sqlwatch_get_check_status] ( @check_warning_threshold, @check_value ) = 1 then 'WARNING'
		else 'OK' end

	----if @check_status is still null then check if its warning, but we may not have warning so need to account for that:
	--select @check_status = case when @check_status is null 
	--			and @check_warning_threshold is not null 
	--			and [dbo].[ufn_sqlwatch_get_check_status] ( @check_warning_threshold, @check_value ) = 1 then 'WARNING' else @check_status end

	----if not warninig or critical then OK
	--if @check_status is null
	--	set @check_status = 'OK'

	-------------------------------------------------------------------------------------------------------------------
	-- log check results:
	-------------------------------------------------------------------------------------------------------------------
	insert into [dbo].[sqlwatch_logger_check] (sql_instance, snapshot_time, snapshot_type_id, check_id, 
		[check_value], [check_status], check_exec_time_ms, [status_change], [is_flapping])
	values (@@SERVERNAME, @snapshot_time, @snapshot_type_id, @check_id, @check_value, @check_status, @check_exec_time_ms, 
		case when isnull(@check_status,'') <> isnull(@previous_check_status,'') then 1 else 0 end,
		@is_flapping )

	-------------------------------------------------------------------------------------------------------------------
	-- process any actions for this check but only if status not OK or previous status was not OK (so we can process recovery)
	-- if current and previous status was OK we wouldnt have any actions anyway so there is no point calling the proc.
	-- assuming 99% of time all checks will come back as OK, this will save significant CPU time
	-------------------------------------------------------------------------------------------------------------------
	if @check_status <> 'OK' or @previous_check_status <> 'OK'
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

				if @@CURSOR_ROWS <> 0
					begin
						/*	logging header here so we only get one header for the batch of actions
							datetime2(0) has a resolution of 1 second and if we had multuple actions, the below
							procedure would have iterated quicker that that causing PK violation on insertion of the subsequent action headers	*/
							exec [dbo].[usp_sqlwatch_internal_insert_header] 
								@snapshot_time_new = @snapshot_time_action OUTPUT,
								@snapshot_type_id = @snapshot_type_id_action

						Print 'Processing actions for check.'
					end
 
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
								@check_description = @check_description,
								@check_name = @check_name,
								@check_threshold_warning = @check_warning_threshold,
								@check_threshold_critical = @check_critical_threshold,
								@snapshot_time = @snapshot_time_action,
								@snapshot_type_id = @snapshot_type_id_action,
								@is_flapping = @is_flapping
						end try
						begin catch
							--28B7A898-27D7-44C0-B6EB-5238021FD855
							set @has_errors = 1				
							set @error_message = 'Errors when processing Action (Id: ' + convert(varchar(10),@action_id) + ') for Check (Id: ' + convert(varchar(10),@check_id) + ')'
							exec [dbo].[usp_sqlwatch_internal_log]
								@proc_id = @@PROCID,
								@process_stage = '28B7A898-27D7-44C0-B6EB-5238021FD855',
								@process_message = @error_message,
								@process_message_type = 'ERROR'
							GoTo NextAction
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
	set last_check_date = @check_end_time,
		last_check_value = @check_value,
		last_check_status = @check_status,
		last_status_change_date = case when @previous_check_status <> @check_status then getutcdate() else last_status_change_date end
	where [check_id] = @check_id
	and sql_instance = @@SERVERNAME

	ProcessNextCheck:

	fetch next from cur_rules 
	into @check_id, @check_name, @check_description , @check_query, @check_warning_threshold, @check_critical_threshold
		, @previous_check_date, @previous_check_value, @previous_check_status, @ignore_flapping
	
end

close cur_rules
deallocate cur_rules


if @has_errors = 1
	begin
		set @error_message = 'Errors during execution (' + OBJECT_NAME(@@PROCID) + ')'
		--print all errors and terminate the batch which will also fail the agent job for the attention:
		raiserror ('%s',16,1,@error_message)
	end