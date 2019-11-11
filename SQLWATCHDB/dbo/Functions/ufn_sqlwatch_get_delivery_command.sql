CREATE FUNCTION [dbo].[ufn_sqlwatch_get_delivery_command]
(
	@address nvarchar(max),
	@title nvarchar(max),
	@content nvarchar(max),
	@attributes nvarchar(max),
	@target_type nvarchar(max)
)
returns nvarchar(max)
AS
begin
	return (select case 

		/* DEPRECATED */

		------------------------------------------------------------------------
		-- format command for sp_send_dbmail
		------------------------------------------------------------------------
		when lower(@target_type) = 'sp_send_dbmail' then
'declare @rtn int
exec @rtn = msdb.dbo.sp_send_dbmail @recipients = ''' + @address + ''',
@subject = ''' + @title + ''',
@body = ''' + replace(@content,'''','''''') + ''',
' + @attributes + '
select error=@rtn'

		------------------------------------------------------------------------
		-- format command for Pushover
		------------------------------------------------------------------------
		when lower(@target_type) = 'pushover' then
'$uri = "' + @address + '"
$parameters = @{
 ' + @attributes + '
  message = "' + @title + '
 ' + replace(@content,'''','''''') + '"}
  
  $parameters | Invoke-RestMethod -Uri $uri -Method Post'

		------------------------------------------------------------------------
		-- format command for Send-MailMessage
		------------------------------------------------------------------------
		when lower(@target_type) = 'send-mailmessage' then
'
$parameters = @{
To = "' + @address + '"
Subject = "' + @title + '"
Body = "' + @content + '"
 ' + @attributes + '
 }
Send-MailMessage @parameters'
	end)
end
