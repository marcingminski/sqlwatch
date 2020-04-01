CREATE PROCEDURE [dbo].[usp_sqlwatch_config_add_action] (
	@action_id smallint = null,
	@action_description nvarchar(max),
	@action_exec_type nvarchar(50),
	@action_exec varchar(max) = null,
	@action_report_id smallint = null,
	@action_enabled bit = 1
)
as

set xact_abort on;
set nocount on;

if @action_id < 0 --to maintain actions shipped with sqlwatch and to be able to insert negative identities
	begin
		merge [dbo].[sqlwatch_config_action] as target
		using (
			select 
				 [action_id] = @action_id
				,[action_description] = @action_description
				,[action_exec_type] = @action_exec_type
				,[action_exec] = @action_exec
				,[action_report_id] = @action_report_id
				,[action_enabled] = @action_enabled
			) as source
			on source.action_id = target.action_id

		when matched and target.[date_updated] is null
			then update
				set  [action_description] = source.[action_description]
					,[action_exec_type] = source.[action_exec_type]
					,[action_exec] = source.[action_exec]
					,[action_report_id] = source.[action_report_id]
					,[action_enabled] = source.[action_enabled]

		--if not matched or action is null we are going to insert new row
		when not matched
			then insert ( [action_id]
						 ,[action_description]
						 ,[action_exec_type]
						 ,[action_exec]
						 ,[action_report_id]
						 ,[action_enabled] )
			values ( source.[action_id]
					,source.[action_description]
					,source.[action_exec_type]
					,source.[action_exec]
					,source.[action_report_id]
					,source.[action_enabled] );
	end
else
	begin
		merge [dbo].[sqlwatch_config_action] as target
		using (
			select 
				 [action_id] = @action_id
				,[action_description] = @action_description
				,[action_exec_type] = @action_exec_type
				,[action_exec] = @action_exec
				,[action_report_id] = @action_report_id
				,[action_enabled] = @action_enabled
			) as source
			on source.action_id = target.action_id

		when matched
			then update
				set  [action_description] = source.[action_description]
					,[action_exec_type] = source.[action_exec_type]
					,[action_exec] = source.[action_exec]
					,[action_report_id] = source.[action_report_id]
					,[action_enabled] = source.[action_enabled]

		--if not matched or action is null we are going to insert new row
		when not matched
			then insert ( [action_description]
						 ,[action_exec_type]
						 ,[action_exec]
						 ,[action_report_id]
						 ,[action_enabled] )
			values ( source.[action_description]
					,source.[action_exec_type]
					,source.[action_exec]
					,source.[action_report_id]
					,source.[action_enabled] );
	end