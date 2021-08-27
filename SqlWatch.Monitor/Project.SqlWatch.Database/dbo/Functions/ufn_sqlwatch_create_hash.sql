CREATE FUNCTION [dbo].[ufn_sqlwatch_create_hash]
(
	@data_to_hash nvarchar(max)
)
RETURNS varbinary(8) with schemabinding
AS
BEGIN
	return (convert(varbinary(8),hashbytes('MD5',@data_to_hash) & convert(bigint,0x7FFFFFFFFFFFFFFF),1))
END
