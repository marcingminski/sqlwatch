CREATE FUNCTION [dbo].[ufn_sqlwatch_get_error_detail_text]()
RETURNS nvarchar(max)
AS
BEGIN
	return (select case when ERROR_MESSAGE() is not null then (
		select 'ERROR_NUMBER=' + isnull(convert(nvarchar(max),ERROR_NUMBER()),'') + char(10) + 
'ERROR_SEVERITY=' + isnull(convert(nvarchar(max),ERROR_SEVERITY()),'') + char(10) + 
'ERROR_STATE=' + isnull(convert(nvarchar(max),ERROR_STATE()),'') + char(10) + 
'ERROR_PROCEDURE=''' + isnull(convert(nvarchar(max),ERROR_PROCEDURE()),'') + '''' + char(10) + 
'ERROR_LINE=' + isnull(convert(nvarchar(max),ERROR_LINE()),'') + char(10) + 
'ERROR_MESSAGE=''' + isnull(convert(nvarchar(max),ERROR_MESSAGE()),'') + ''''
		) else null end
		)

END