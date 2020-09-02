CREATE FUNCTION [dbo].[ufn_sqlwatch_convert_time_utc]
(
	@local_time datetime
)
RETURNS datetime WITH SCHEMABINDING
AS
BEGIN
	-- the dbo.ufn_sqlwatch_get_server_utc_offset() gives the offset from the UTC time to local time.
	-- if we want to go back from local to UTC, we have to substract it.
	-- for time zones behind UTC it will be a double negative which turns into a positive
	RETURN dateadd(Hour,dbo.ufn_sqlwatch_get_server_utc_offset('HOUR')*-1,@local_time)
END
