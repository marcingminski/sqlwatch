CREATE FUNCTION [dbo].[ufn_sqlwatch_get_servername]()

RETURNS varchar(32) with schemabinding
AS
BEGIN
	-- this has two purposes.
	-- first we do explicit conversion in a single place
	-- second, we can manipulate the @@SERVERNAME, handy on the managed instances where server names can be 255 char long.
	RETURN convert(varchar(32),@@SERVERNAME);
END;
