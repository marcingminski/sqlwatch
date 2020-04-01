CREATE PROCEDURE [dbo].[usp_sqlwatch_config_add_report] (
	@sql_instance varchar(32) = @@SERVERNAME,
	@report_id smallint = null,
	@report_title varchar(255) ,
	@report_description varchar(4000) = null,
	@report_definition nvarchar(max) ,
	@report_definition_type varchar(10) ,
	@report_active bit = 1,
	@report_batch_id varchar(255) = null,
	@report_style_id smallint = null ,
	--action to assosiate report with, in case of multiple actions, rerun the procedure with the same params but different action id
	@report_action_id smallint = null
)
as

set xact_abort on;
set nocount on;

set @report_style_id = case 
	when @report_style_id is null and @report_definition_type <> 'Query' then -1 
	when @report_style_id is not null and @report_definition_type = 'Query' then null
	else @report_style_id end

if @report_id < 0 
	begin
		merge [dbo].[sqlwatch_config_report] as target
		using ( select
				 [report_id] = @report_id
				,[report_title] = @report_title
				,[report_description] = @report_description
				,[report_definition] = @report_definition
				,[report_definition_type] = @report_definition_type
				,[report_active] = @report_active
				,[report_batch_id] = @report_batch_id
				,[report_style_id] = @report_style_id
		) as source
		on source.report_id = target.report_id

		when not matched then
			insert ( [report_id]
					,[report_title]
					,[report_description]
					,[report_definition]
					,[report_definition_type]
					,[report_active]
					,[report_batch_id]
					,[report_style_id])
			values ( source.[report_id]
					,source.[report_title]
					,source.[report_description]
					,source.[report_definition]
					,source.[report_definition_type]
					,source.[report_active]
					,source.[report_batch_id]
					,source.[report_style_id])

		when matched and target.[date_updated] is null then
			update
				set  [report_title] = source.[report_title]
					,[report_description] = source. [report_description]
					,[report_definition] = source.[report_definition]
					,[report_definition_type] = source.[report_definition_type]
					,[report_active] = source.[report_active]
					,[report_batch_id] = source.[report_batch_id]
					,[report_style_id] = source.[report_style_id]
		;
	end
else
	begin
		merge [dbo].[sqlwatch_config_report] as target
		using ( select
				 [report_id] = @report_id
				,[report_title] = @report_title
				,[report_description] = @report_description
				,[report_definition] = @report_definition
				,[report_definition_type] = @report_definition_type
				,[report_active] = @report_active
				,[report_batch_id] = @report_batch_id
				,[report_style_id] = @report_style_id
		) as source
		on source.report_id = target.report_id

		when not matched then
			insert ( [report_title]
					,[report_description]
					,[report_definition]
					,[report_definition_type]
					,[report_active]
					,[report_batch_id]
					,[report_style_id])
			values ( source.[report_title]
					,source.[report_description]
					,source.[report_definition]
					,source.[report_definition_type]
					,source.[report_active]
					,source.[report_batch_id]
					,source.[report_style_id])

		when matched then
			update
				set  [report_title] = source.[report_title]
					,[report_description] = source. [report_description]
					,[report_definition] = source.[report_definition]
					,[report_definition_type] = source.[report_definition_type]
					,[report_active] = source.[report_active]
					,[report_batch_id] = source.[report_batch_id]
					,[report_style_id] = source.[report_style_id]
		;

		Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') updated.'
	end


if @report_action_id is not null
	begin
		insert into [dbo].[sqlwatch_config_report_action] ( [report_id] ,[action_id] )

		select [s].[report_id], [s].[action_id]
		from (
			select 
				 [report_id] = @report_id
				,[action_id] = @report_action_id
			) s

		left join [dbo].[sqlwatch_config_report_action] t
			on t.report_id = s.[report_id]
			and t.action_id = s.action_id

		where t.action_id is null

		if (@@ROWCOUNT > 0)
			begin
				Print 'Report (Id: ' + convert(varchar(10),@report_id) + ') assosiated with action (Id: ' + convert(varchar(10),@report_action_id) + ').'
			end

	end