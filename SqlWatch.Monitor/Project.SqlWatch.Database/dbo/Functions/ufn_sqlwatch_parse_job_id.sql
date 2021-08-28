CREATE FUNCTION [dbo].[ufn_sqlwatch_parse_job_id]
(
	@client_app_name nvarchar(256)
)
RETURNS uniqueidentifier with schemabinding
AS
BEGIN
	RETURN (select convert(uniqueidentifier,case when @client_app_name like 'SQLAGent - TSQL JobStep%' then convert(varbinary,left(replace(@client_app_name collate DATABASE_DEFAULT,'SQLAgent - TSQL JobStep (Job ',''),34),1) else null end));
END;
