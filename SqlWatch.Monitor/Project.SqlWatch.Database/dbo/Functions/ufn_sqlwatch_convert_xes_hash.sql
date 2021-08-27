CREATE FUNCTION [dbo].[ufn_sqlwatch_convert_xes_hash]
(
	@xes_hash decimal(20,0)
)
RETURNS varbinary(8) with schemabinding
AS
BEGIN
	RETURN (select case when @xes_hash = 0 or @xes_hash is null then null else convert(varbinary(8),convert(varbinary,@xes_hash,1) & convert(bigint,0x7FFFFFFFFFFFFFFF)) end)
END
