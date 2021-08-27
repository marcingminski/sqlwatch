CREATE FUNCTION [dbo].[ufn_sqlwatch_convert_local_to_utctime]
(
	@local_time datetime2(3)
)
RETURNS datetime2(3)
AS
BEGIN
	--I am not 100% convinced this will cover edge cases when the daylight changes
	RETURN dateadd(minute,(datepart(TZOFFSET,SYSDATETIMEOFFSET()))*-1,@local_time);
END;