CREATE FUNCTION [dbo].[ufn_sqlwatch_get_time_group]
(
	@report_time as datetime2(0),
	@time_internval_minutes int
)
RETURNS smalldatetime
AS
BEGIN
	RETURN convert(smalldatetime,dateadd(minute,(datediff(minute,0, @report_time)/ @time_internval_minutes) * @time_internval_minutes,0))
END
