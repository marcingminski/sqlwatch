CREATE PROCEDURE [dbo].[usp_sqlwatch_user_add_report] (
	@sql_instance varchar(32) = @@SERVERNAME,
	@report_id smallint = null,
	@report_title varchar(255) ,
	@report_description varchar(4000) = null,
	@report_definition nvarchar(max) ,
	@report_definition_type varchar(10) ,
	@report_active bit = 1,
	@report_batch_id tinyint = null,
	@report_style_id smallint = -1,
	--action to assosiate report with, in case of multiple actions, rerun the procedure with the same params but different action id
	@report_action_id smallint = null
)
as

set xact_abort on;
set nocount on;

if @report_id is not null 
	begin
		--if report id passed we are going to use it as an identity.
		--if there is an existing report with this id, we are going to update it
		--this is primarly to maintain default reports shipped with SQLWATCH. They will have negative IDs

		if exists ( select * from [dbo].[sqlwatch_config_report]
					where [sql_instance] = @sql_instance
					and [report_id] = @report_id )
			begin
				update [dbo].[sqlwatch_config_report]
					set  [report_title] = @report_title
						,[report_description] = @report_description
						,[report_definition] = @report_definition
						,[report_definition_type] = @report_definition_type
						,[report_active] = @report_active
						,[report_batch_id] = @report_batch_id
						,[report_style_id] = @report_style_id
				where [report_id] = @report_id
				and [sql_instance] = @sql_instance

				Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') updated.'
			end
		else
			begin
				set identity_insert [dbo].[sqlwatch_config_report] on 
				insert into [dbo].[sqlwatch_config_report]
								   ([sql_instance]
								   ,[report_id]
								   ,[report_title]
								   ,[report_description]
								   ,[report_definition]
								   ,[report_definition_type]
								   ,[report_active]
								   ,[report_batch_id]
								   ,[report_style_id]
								   )
				values (@sql_instance, @report_id, @report_title, @report_description, @report_definition, @report_definition_type, @report_active, @report_batch_id, @report_style_id)
				set identity_insert [dbo].[sqlwatch_config_report] off 

				Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') created.'
			end

	end
else
	begin
		--if no report id passed we are going to create a new one with default identity:
		insert into [dbo].[sqlwatch_config_report]
						   ([sql_instance]
						   ,[report_title]
						   ,[report_description]
						   ,[report_definition]
						   ,[report_definition_type]
						   ,[report_active]
						   ,[report_batch_id]
						   ,[report_style_id]
						   )
		values (@sql_instance, @report_title, @report_description, @report_definition, @report_definition_type, @report_active, @report_batch_id, @report_style_id)
		select @report_id = SCOPE_IDENTITY()
		Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') created.'
	end


--if @report_actions is passed, assosiate report with given actions
--list must comma separated

if @report_action_id is not null
	begin
		insert into [dbo].[sqlwatch_config_report_action] ( [sql_instance], [report_id] ,[action_id] )

		select [s].[sql_instance], [s].[report_id], [s].[action_id]
		from (
			select 
				 [sql_instance] = @@SERVERNAME
				,[report_id] = @report_id
				,[action_id] = @report_action_id
			) s

		left join [dbo].[sqlwatch_config_report_action] t
			on t.sql_instance = s.sql_instance
			and t.report_id = s.[report_id]
			and t.action_id = s.action_id

		where t.action_id is null

		if (@@ROWCOUNT > 0)
			begin
				Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') assosiated with action (Id: ' + convert(varchar(10),@report_action_id) + ').'
			end

	end

