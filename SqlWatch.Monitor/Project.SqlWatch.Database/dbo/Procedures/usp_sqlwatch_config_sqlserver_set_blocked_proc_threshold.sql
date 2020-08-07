CREATE PROCEDURE [dbo].[usp_sqlwatch_config_sqlserver_set_blocked_proc_threshold]
	@threshold_seconds int = 15
AS
exec sp_configure 'show advanced options', 1 ;  
RECONFIGURE ;  
exec sp_configure 'blocked process threshold', @threshold_seconds ;  
RECONFIGURE ;  