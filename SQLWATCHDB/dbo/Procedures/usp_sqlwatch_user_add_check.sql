CREATE PROCEDURE [dbo].[usp_sqlwatch_user_add_check] (
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
	@action_template_id smallint = -1 --default template shipped with SQLWATCH
)
as

set xact_abort on;
set nocount on;

if @check_id is not null 
	begin
		--if check id passed we are going to use it as an identity.
		--if there is an existing check with this id, we are going to update it
		--this is primarly to maintain default checks shipped with SQLWATCH. They will have negative IDs

		if exists ( select * from [dbo].[sqlwatch_config_check]
					where [sql_instance] = @sql_instance
					and [check_id] = @check_id )
			begin
				update [dbo].[sqlwatch_config_check]
					set  [check_name] = @check_name
						,[check_description] = @check_description
						,[check_query] = @check_query
						,[check_frequency_minutes] = @check_frequency_minutes
						,[check_threshold_warning] = @check_threshold_warning
						,[check_threshold_critical] = @check_threshold_critical
						,[check_enabled] = @check_enabled
				where check_id = @check_id
				and sql_instance = @sql_instance

				Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') updated.'
			end
		else
			begin
				set identity_insert [dbo].[sqlwatch_config_check] on 
				insert into [dbo].[sqlwatch_config_check]
								   (   [sql_instance]
									  ,[check_id]
									  ,[check_name]
									  ,[check_description]
									  ,[check_query]
									  ,[check_frequency_minutes]
									  ,[check_threshold_warning]
									  ,[check_threshold_critical]
									  ,[check_enabled]
								   )
				values (@sql_instance, @check_id, @check_name, @check_description, @check_query, @check_frequency_minutes
						, @check_threshold_warning, @check_threshold_critical, @check_enabled)
				set identity_insert [dbo].[sqlwatch_config_check] off 

				Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') created.'
			end
	end
else
	begin
		--if no check id passed we are going to create a new one with default identity:
		insert into [dbo].[sqlwatch_config_check]
							(   [sql_instance]
								,[check_name]
								,[check_description]
								,[check_query]
								,[check_frequency_minutes]
								,[check_threshold_warning]
								,[check_threshold_critical]
								,[check_enabled]
							)
			values (@sql_instance, @check_name, @check_description, @check_query, @check_frequency_minutes
						, @check_threshold_warning, @check_threshold_critical, @check_enabled)
		select @check_id = SCOPE_IDENTITY()
		Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') created.'
	end

--if @check_actions is passed, assosiate check with given actions
--list must comma separated

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
		on source.sql_instance = target.sql_instance
		and source.check_id = target.check_id
		and source.action_id = target.action_id

		when not matched then
		insert ([sql_instance]
				,[check_id],[action_id],[action_every_failure],[action_recovery]
				,[action_repeat_period_minutes],[action_hourly_limit],[action_template_id])

		values (source.[sql_instance], source.[check_id], source.[action_id], source.[action_every_failure], source.[action_recovery]
			 , source.[action_repeat_period_minutes], source.[action_hourly_limit], source.[action_template_id])

		when matched then 
			update set
				 [sql_instance]= source.sql_instance
				,[check_id] = source.check_id
				,[action_id] = source.action_id
				,[action_every_failure] = source.action_every_failure
				,[action_recovery] = source.action_recovery
				,[action_repeat_period_minutes] = source.action_repeat_period_minutes
				,[action_hourly_limit] = source.action_hourly_limit
				,[action_template_id] = source.action_template_id;

		Print 'Check (Id: ' + convert(varchar(10),@check_id) + ') assosiated with action (Id: ' + convert(varchar(10),@check_action_id) + ').'
	end