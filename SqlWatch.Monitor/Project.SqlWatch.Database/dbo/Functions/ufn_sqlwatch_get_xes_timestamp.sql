CREATE FUNCTION [dbo].[ufn_sqlwatch_get_xes_timestamp]
(
	@event_data nvarchar(max)
)
RETURNS datetime2(0) with schemabinding
AS
BEGIN
	RETURN (select substring(@event_data,PATINDEX('%timestamp%',@event_data)+len('timestamp="'),24));
END;
