CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_update_xes_query_count]
	@session_name nvarchar(64),
	@execution_count bigint
AS
	update [dbo].[sqlwatch_stage_xes_exec_count]
	set  execution_count = @execution_count
		, last_updated = getutcdate()
	where session_name = @session_name
	option (keep plan);
RETURN 0
