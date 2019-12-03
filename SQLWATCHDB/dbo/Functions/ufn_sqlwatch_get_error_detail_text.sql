CREATE FUNCTION [dbo].[ufn_sqlwatch_get_error_detail_text]()
RETURNS nvarchar(max)
AS
BEGIN
	return (
		select '^ERROR_NUMBER=' + isnull(convert(nvarchar(max),ERROR_NUMBER()),'') + char(10) + 
'^ERROR_SEVERITY=' + isnull(convert(nvarchar(max),ERROR_SEVERITY()),'') + char(10) + 
'^ERROR_STATE=' + isnull(convert(nvarchar(max),ERROR_STATE()),'') + char(10) + 
'^ERROR_PROCEDURE=' + isnull(convert(nvarchar(max),ERROR_PROCEDURE()),'') +  char(10) + 
'^ERROR_LINE=' + isnull(convert(nvarchar(max),ERROR_LINE()),'') + char(10) + 
'^ERROR_MESSAGE=' + isnull(convert(nvarchar(max),ERROR_MESSAGE()),'') + char(10) 
--'^SERVERNAME=' + isnull(convert(nvarchar(max),@@SERVERNAME),'') + char(10) + 
--'^DATABASE_NAME=' + isnull(convert(nvarchar(max),DB_NAME()),'') + char(10) + 
--'^CALLER_PROC_NAME=' + isnull(convert(nvarchar(max),object_name(@exec_proc_id)),'') + char(10) + 
--'^SPID=' + isnull(convert(nvarchar(max),@@SPID),'') + char(10) + 
--'^LOGIN=' + isnull(convert(nvarchar(max),SYSTEM_USER),'') + char(10) + 
--'^USER=' + isnull(convert(nvarchar(max),USER),'') + char(10) + 
--'^APP_STAGE=' + isnull(convert(nvarchar(max),@user_stage),'') + char(10) + 
--'^APP_MESSAGE=' + isnull(convert(nvarchar(max),@user_message),'')
		)
END