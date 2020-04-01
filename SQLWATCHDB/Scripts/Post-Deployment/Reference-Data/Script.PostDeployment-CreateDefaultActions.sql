/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
disable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];
set identity_insert [dbo].[sqlwatch_config_action] on;

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -1
	,@action_description = 'Send Email to DBAs using sp_send_mail  (HTML)'
	,@action_exec_type = 'T-SQL'
	,@action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''dba@yourcompany.com'',
@subject = ''{SUBJECT}'',
@body = ''{BODY}'',
@profile_name=''SQLWATCH'',
@body_format = ''HTML'''
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -2
	,@action_description = 'Send Email to DBAs using sp_send_mail'
	,@action_exec_type = 'T-SQL'
	,@action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''dba@yourcompany.com'',
@subject = ''{SUBJECT}'',
@body = ''{BODY}'',
@profile_name=''SQLWATCH'''
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -3
	,@action_description = 'Push notifiction via Pushover'
	,@action_exec_type = 'PowerShell'
	,@action_exec = '$uri = "https://api.pushover.net/1/messages.json"
$parameters = @{
  token = "YOUR_TOKEN"
  user = "USER_TOKEN"
  message = "{SUBJECT} {BODY}"
}
$parameters | Invoke-RestMethod -Uri $uri -Method Post'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -4
	,@action_description = 'Send Email using Send-MailMessage and external SMTP'
	,@action_exec_type = 'PowerShell'
	,@action_exec = 'Send-MailMessage -From ''DBA <dba@yourcompany.com>'' -To ''dba@yourcompany.com'' -Subject "{SUBJECT}" -Body "{BODY}" -SmtpServer "smtp.yourcompany.com"'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -5
	,@action_description = 'Save File on Shared Drive'
	,@action_exec_type = 'PowerShell'
	,@action_exec = '"{BODY}" | Out-File -FilePath \\yourshare\Folder\export.csv'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -6
	,@action_description = 'Send Alert to ZABBIX'
	,@action_exec_type = 'PowerShell'
	,@action_exec = 'zabbix_sender.exe -z zabbix.yourcompany.com -s "SQL_INSTANCE" -k your.check.name -o "{BODY}"'
	,@action_enabled = 0

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -16
	,@action_description = 'Send to Azure Log Monitor. Download cmdlet from https://www.powershellgallery.com/packages/Upload-AzMonitorLog/1.2'
	,@action_exec_type = 'PowerShell'
	,@action_exec = 'Invoke-Sqlcmd -ServerInstance localhost -Database $(DatabaseName) -Query "{BODY}" | C:\SQLWATCHPS\Upload-AzMonitorLog.ps1 -WorkspaceId YOURWORKSPACEID -WorkspaceKey YOURWORKSPACEKEY -LogTypeName "{SUBJECT}" -AddComputerName'
	,@action_enabled = 0

set identity_insert [dbo].[sqlwatch_config_action] off;
enable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];