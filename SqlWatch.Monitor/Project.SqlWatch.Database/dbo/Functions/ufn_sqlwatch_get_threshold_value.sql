CREATE FUNCTION [dbo].[ufn_sqlwatch_get_threshold_value]
(
	@threshold varchar(50)
)
RETURNS decimal(28,5) with schemabinding
AS
BEGIN

	return convert(decimal(28,5),replace(@threshold,[dbo].[ufn_sqlwatch_get_threshold_comparator](@threshold),''))

END
