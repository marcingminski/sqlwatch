CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_start_xes]
	@force_start bit = 0
AS


/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_config_start_xes

 Description:
	Start SQLWATCH extended event sessions. 
	Visual Studio has no way of starting up sessions post deployment.

 Parameters
	@force_start	by default we are only starting up SQLWATCH sessions on first deployment but if a user disables
					the session post deployment, we should never attempt to start it again.

 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-01-15	Marcin Gminski, Initial version
-------------------------------------------------------------------------------------------------------------------
*/


if (select count(*) from dbo.sqlwatch_app_version) = 0 or @force_start = 1
	begin
		  declare @sql nvarchar(max) = ''
		  select @sql = @sql + 'ALTER EVENT SESSION ' + quotename(name)+ '
ON SERVER  
STATE = START;' + char(10) +
'Print ''Starting up XE Session: ' + name + ';''' + char(10) + char(10) 
		  from sys.server_event_sessions
		  where name like 'SQLWATCH%'
		  
		  --exclude any running sessions:
		  and name not in (
			select name
			from sys.dm_xe_sessions
			)

		exec (@sql)
	end