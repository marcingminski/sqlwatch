CREATE FUNCTION [dbo].[ufn_sqlwatch_convert_pages_to_bytes]
(
	@pages bigint
)
RETURNS bigint with schemabinding
AS
BEGIN
	RETURN (@pages * 8 * 1024)
END;