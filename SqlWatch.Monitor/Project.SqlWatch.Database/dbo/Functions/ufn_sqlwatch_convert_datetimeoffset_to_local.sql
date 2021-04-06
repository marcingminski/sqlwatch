CREATE FUNCTION [dbo].[ufn_sqlwatch_convert_datetimeoffset_to_local] 
(
	@datetimeoffset datetimeoffset
)

returns datetime2(0) 
with schemabinding
as
begin
	return convert(datetime, switchoffset(convert(datetime, @datetimeoffset), datename(TzOffset, @datetimeoffset)))
end
