CREATE PROCEDURE [dbo].[usp_sqlwatch_config_add_check] (
	@sql_instance varchar(32) = @@SERVERNAME,
	@check_id smallint = null,
	@check_name nvarchar(50),
	@check_description nvarchar(2048),
	@check_query nvarchar(max), --the sql query to execute to check for value, the return should be a one row one value which will be compared against thresholds. 
	@check_frequency_minutes smallint = null, --how often to run this check, by default the ALERT agent job runs every 2 minutes but we may not want to run all checks every 2 minutes.
	@check_threshold_warning varchar(100) = null, --warning is optional
	@check_threshold_critical varchar(100), --but critical is not. we have to check against something. 
	@check_enabled bit = 1, --if enabled the check will be processed
	@check_action_id smallint = null, --assosiate check with actions

	--action assosiation specifics. In order to assosiate check with multiple actions, rerun the proc with new action
	@action_every_failure bit = 0,
	@action_recovery bit = 1,
	@action_repeat_period_minutes smallint = null,
	@action_hourly_limit smallint = 2,
	@action_template_id smallint = -1, --default template shipped with SQLWATCH
	@ignore_flapping bit = 0
)
as

set xact_abort on;
set nocount on;

if @check_id < 0
	begin
		merge [dbo].[sqlwatch_config_check] as target
		using ( select
				 [check_id] = @check_id
				,[check_name] = @check_name
				,[check_description] = @check_description
				,[check_query] = @check_query
				,[check_frequency_minutes] = @check_frequency_minutes
				,[check_threshold_warning] = @check_threshold_warning
				,[check_threshold_critical] = @check_threshold_critical
				,[check_enabled] = @check_enabled
				,[ignore_flapping] = @ignore_flapping
			) as source
		on source.check_id = target.check_id

		when not matched then
			insert ( [check_id]
					,[check_name]
					,[check_description]
					,[check_query]
					,[check_frequency_minutes]
					,[check_threshold_warning]
					,[check_threshold_critical]
					,[check_enabled]
					,[ignore_flapping]
				   )
			values ( source.[check_id]
					,source.[check_name]
					,source.[check_description]
					,source.[check_query]
					,source.[check_frequency_minutes]
					,source.[check_threshold_warning]
					,source.[check_threshold_critical]
					,source.[check_enabled]
					,source.[ignore_flapping])

		when matched and target.[date_updated] is null 
			then update 
				set
				 [check_name] = source.[check_name]
				,[check_description] = source.[check_description]
				,[check_query] = source.[check_query]
				,[check_frequency_minutes] = source.[check_frequency_minutes]
				,[check_threshold_warning] = source.[check_threshold_warning]
				,[check_threshold_critical] = source.[check_threshold_critical]
				,[check_enabled] = source.[check_enabled]
				,[ignore_flapping] = source.[ignore_flapping];
	end
else
	begin
		merge [dbo].[sqlwatch_config_check] as target
		using ( select
				 [check_id] = @check_id
				,[check_name] = @check_name
				,[check_description] = @check_description
				,[check_query] = @check_query
				,[check_frequency_minutes] = @check_frequency_minutes
				,[check_threshold_warning] = @check_threshold_warning
				,[check_threshold_critical] = @check_threshold_critical
				,[check_enabled] = @check_enabled
				,[ignore_flapping] = @ignore_flapping
			) as source
		on source.check_id = target.check_id

		when not matched then
			insert ( [check_name]
					,[check_description]
					,[check_query]
					,[check_frequency_minutes]
					,[check_threshold_warning]
					,[check_threshold_critical]
					,[check_enabled]
					,[ignore_flapping]
				   )
			values ( source.[check_name]
					,source.[check_description]
					,source.[check_query]
					,source.[check_frequency_minutes]
					,source.[check_threshold_warning]
					,source.[check_threshold_critical]
					,source.[check_enabled]
					,source.[ignore_flapping])

		when matched then
			update set
				 [check_name] = source.[check_name]
				,[check_description] = source.[check_description]
				,[check_query] = source.[check_query]
				,[check_frequency_minutes] = source.[check_frequency_minutes]
				,[check_threshold_warning] = source.[check_threshold_warning]
				,[check_threshold_critical] = source.[check_threshold_critical]
				,[check_enabled] = source.[check_enabled]
				,[ignore_flapping] = source.[ignore_flapping];

			Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') updated.'
	end

if @check_action_id is not null
	begin
		merge [dbo].[sqlwatch_config_check_action] as target
		using (
				select
				 [sql_instance]=@@SERVERNAME
				,[check_id] = @check_id
				,[action_id] = @check_action_id
				,[action_every_failure] = @action_every_failure
				,[action_recovery] = @action_recovery
				,[action_repeat_period_minutes] = @action_repeat_period_minutes
				,[action_hourly_limit] = @action_hourly_limit
				,[action_template_id] = @action_template_id
			 ) as source
		on source.check_id = target.check_id
		and source.action_id = target.action_id

		when not matched then
		insert ( [check_id],[action_id]
				,[action_every_failure]
				,[action_recovery]
				,[action_repeat_period_minutes]
				,[action_hourly_limit]
				,[action_template_id])

		values (  source.[check_id]
				, source.[action_id]
				, source.[action_every_failure]
				, source.[action_recovery]
				, source.[action_repeat_period_minutes]
				, source.[action_hourly_limit]
				, source.[action_template_id])

		when matched and target.[date_updated] is null then 
			update set
				 [check_id] = source.check_id
				,[action_id] = source.action_id
				,[action_every_failure] = source.action_every_failure
				,[action_recovery] = source.action_recovery
				,[action_repeat_period_minutes] = source.action_repeat_period_minutes
				,[action_hourly_limit] = source.action_hourly_limit
				,[action_template_id] = source.action_template_id;

		Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') assosiated with action (Id: ' + convert(varchar(10),@check_action_id) + ').'
	end