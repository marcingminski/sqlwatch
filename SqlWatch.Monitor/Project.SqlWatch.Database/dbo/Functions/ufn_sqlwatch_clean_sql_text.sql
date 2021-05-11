CREATE FUNCTION [dbo].[ufn_sqlwatch_clean_sql_text] 
(
	@sql_text varchar(max)
) 
RETURNS varchar(max) with schemabinding
AS
BEGIN
	RETURN (
		replace(replace(replace(replace(replace(@sql_text,char(9), ''),char(10),'') ,' ',char(9)+char(10)),char(10)+char(9),''),char(9)+char(10),' ')
	)
END
