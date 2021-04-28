CREATE FUNCTION [dbo].[ufn_sqlwatch_get_delta_value]
(
	@value_previous real,
	@value_current real
)
RETURNS real with schemabinding
AS
BEGIN
	RETURN (select convert(real,case when @value_current > @value_previous then @value_current  - isnull(@value_previous,0) else 0 end))
END
