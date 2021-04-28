CREATE FUNCTION [dbo].[ufn_sqlwatch_get_xes_exec_time]
(
	@session_name nvarchar(64)
)
RETURNS datetime2(0) with schemabinding
AS
BEGIN
	RETURN (
		select [last_updated]
		from [dbo].[sqlwatch_stage_xes_exec_count]
		where session_name = @session_name
	)
END
