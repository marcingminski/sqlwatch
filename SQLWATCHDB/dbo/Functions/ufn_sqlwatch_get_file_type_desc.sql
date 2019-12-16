CREATE FUNCTION [dbo].[ufn_sqlwatch_get_file_type_desc] 
(
	@file_type tinyint
) 
RETURNS varchar(max)
with schemabinding
AS
BEGIN
/* https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql
		
File type:
0 = Rows.
1 = Log
2 = FILESTREAM
3 = Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
4 = Full-text (Full-text catalogs earlier than SQL Server 2008; full-text catalogs that are upgraded to or created in SQL Server 2008 or higher will report a file type 0.)

*/
		return  case @file_type
			when 0 then 'Rows'
			when 1 then 'Log'
			when 2 then 'FILESTREAM'
			when 3 then '3'
			when 4 then 'Full-text'
		else 'UNKNOWN' end
END
