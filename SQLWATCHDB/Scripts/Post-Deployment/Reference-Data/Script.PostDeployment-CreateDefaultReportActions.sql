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
	 @action_id = -7
	,@action_description = 'Run Failed Agent Jobs Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -2
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -8
	,@action_description = 'Run Blocked Process Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -3
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -9
	,@action_description = 'Run Disk Utilisation Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -4
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -10
	,@action_description = 'Run Backup Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -5
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -11
	,@action_description = 'Out of date Log Backup Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -6
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -12
	,@action_description = 'Out of date Backup Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -7
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -13
	,@action_description = 'Missing Data Backup Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -8
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -14
	,@action_description = 'Missing Log Backup Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -9
	,@action_enabled = 1

exec [dbo].[usp_sqlwatch_config_add_action]
	 @action_id = -15
	,@action_description = 'Long Open Transactions Report'
	,@action_exec_type = 'T-SQL'
	,@action_report_id = -10
	,@action_enabled = 1


set identity_insert [dbo].[sqlwatch_config_action] off;
enable trigger dbo.trg_sqlwatch_config_action_updated_U ON [dbo].[sqlwatch_config_action];