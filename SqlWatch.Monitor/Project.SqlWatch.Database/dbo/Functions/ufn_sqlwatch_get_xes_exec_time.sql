CREATE FUNCTION [dbo].[ufn_sqlwatch_get_xes_exec_time]
(
	@session_name nvarchar(64)
)
-- TO DO TODO CAN BE REMOVED IN vNEXT
RETURNS datetime2(0) with schemabinding
AS
BEGIN
	RETURN (
		select last_event_time
		from [dbo].[sqlwatch_stage_xes_exec_count]
		where session_name = @session_name
	)
END
