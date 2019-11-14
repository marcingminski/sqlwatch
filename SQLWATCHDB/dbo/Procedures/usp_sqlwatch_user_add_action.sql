CREATE PROCEDURE [dbo].[usp_sqlwatch_user_add_action] (
	@action_id smallint = null,
	@action_description nvarchar(max),
	@action_exec_type nvarchar(50),
	@action_exec varchar(max) = null,
	@action_report_id smallint = null,
	@action_enabled bit = 1,
	@force_update bit = 0
)
as

set xact_abort on;
set nocount on;

if @action_id is not null 
	begin
		--if action id passed we are going to use it as an identity.
		--if there is an existing action with this id, we are going to update it

		--however, if someone has adopted and modified default actions
		--we must not replace user settings so need to check for the content of exec column
		if exists ( select * from [dbo].[sqlwatch_config_action]
					where [action_id] = @action_id )
			begin
				update [dbo].[sqlwatch_config_action]
					set  [action_description] = @action_description
						,[action_exec_type] = @action_exec_type
						,[action_exec] = @action_exec
						,[action_report_id] = @action_report_id
						,[action_enabled] = @action_enabled
				where [action_id] = @action_id
				--check if default action (id < 0) and the content is different
				--actions with positive id (id > 0) as user actions and we will update as required
				and 1 = case when @action_id < 0 and [action_exec] <> @action_exec then 0 else 1 end

				Print 'Action (Id: ' + convert(varchar(10),@action_id) + ') updated.'
			end
		else
			begin
				if (
						(
							@action_report_id is not null 
							and exists ( select * from [dbo].[sqlwatch_config_report] where report_id = @action_report_id )
						 )
						 or @action_report_id is null
					)
					begin
						set identity_insert [dbo].[sqlwatch_config_action] on 
						insert into [dbo].[sqlwatch_config_action] 
										( [action_id]
										 ,[action_description]
										 ,[action_exec_type]
										 ,[action_exec]
										 ,[action_report_id]
										 ,[action_enabled]
										)

						values (@action_id, @action_description, @action_exec_type, @action_exec, @action_report_id, @action_enabled)
						set identity_insert [dbo].[sqlwatch_config_action] off 

						Print 'Report (Id: ' + convert(varchar(10),@action_id) + ') created.'
					end
				else
					begin
						declare @msg nvarchar(max) = 'Action cannot be created because the referenced report (Id: ' + convert(varchar(10),@action_report_id) + ') does not exist'
						raiserror (@msg,16,1)
					end
			end


	end