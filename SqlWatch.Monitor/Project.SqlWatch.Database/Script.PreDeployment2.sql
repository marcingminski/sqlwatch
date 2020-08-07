/*
 Pre-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.	
 Use SQLCMD syntax to include a file in the pre-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the pre-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/


/* support for XE sessions in VS is dissapointing. VS will create new/missing session but will not alter existing.
	To work around this we can drop sessions manually however, doing it here, in the pre-deployment script is too late.
	At this point the deployment is planned and if we drop sessions now they will not be re-created. To work around this, 
	there is similar step in Post-deployment script */
--Print 'Stoppring SQLWATCH XE Sessions'
--declare @sqlstmt varchar(4000) = ''

--select @sqlstmt = @sqlstmt + 'DROP EVENT SESSION [' + name + '] ON SERVER;' + char(10) 
--from sys.server_event_sessions 
--where name in (	'SQLWATCH_blockers', 'SQLWATCH_waits','SQLWATCH_long_queries')

--exec (@sqlstmt)



:r .\Scripts\Pre-Deployment\SetDacVersion.sql

declare @dacverion varchar(max)
set @dacverion = '$(DacVersion)'

