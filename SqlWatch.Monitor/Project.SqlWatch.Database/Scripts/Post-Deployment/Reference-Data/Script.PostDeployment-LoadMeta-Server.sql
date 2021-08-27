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

merge dbo.sqlwatch_config_sql_instance as target
using (select [servername] = @@SERVERNAME, [repo_collector_is_active] = 0) as source
on target.sql_instance = source.[servername]
when not matched then
	insert (sql_instance, [repo_collector_is_active])
	values (source.[servername], source.[repo_collector_is_active]);


exec  [dbo].[usp_sqlwatch_local_meta_add];

declare @i tinyint = 0

while (select count(*) from [dbo].[sqlwatch_meta_server]) = 0 and @i <= 12
	begin
		Print 'Waiting for queue to process metadata...';

		waitfor delay '00:00:05';

		set @i = @i + 1;
	end;
