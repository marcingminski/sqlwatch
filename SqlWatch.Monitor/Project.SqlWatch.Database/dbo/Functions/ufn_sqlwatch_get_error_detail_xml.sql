CREATE FUNCTION [dbo].[ufn_sqlwatch_get_error_detail_xml]()
RETURNS xml
AS
BEGIN
	return (select case when ERROR_MESSAGE() is not null then (
		select	ERROR_NUMBER=ERROR_NUMBER(),
				ERROR_SEVERITY=ERROR_SEVERITY(),
				ERROR_STATE=ERROR_STATE(),
				ERROR_PROCEDURE=ERROR_PROCEDURE(), 
				ERROR_LINE=ERROR_LINE(),
				ERROR_MESSAGE=ERROR_MESSAGE()
		for xml path ('ERROR')
		) else null end)
END
