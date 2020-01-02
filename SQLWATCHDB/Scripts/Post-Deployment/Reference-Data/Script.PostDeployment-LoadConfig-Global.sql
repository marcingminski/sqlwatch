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


Print 'Populating dbo.sqlwatch_config...'

declare @config table (
	config_id int,
	config_name varchar(255),
	config_value nvarchar(max)
	)
insert into @config (config_id, config_name, config_value)
values
	(1	,'Application Log (app_log) retention days'			,30),
	(2	,'Last Seen Items (date_last_seen) retention days'	,30),
	(3	,'Action Queue Failed Items retention days'			,30),
	(4	,'Action Queue Success Items retention days'		,7),
	(5	,'Last Seen Items purge batch size'					,100),
	(6	,'Logger Retention batch size'						,500),
	(7	,'Logger Log Info messages'							,1)

;

merge dbo.sqlwatch_config as target
using @config as source
on target.config_id = source.config_id
when not matched then 
	insert (config_id, config_name, config_value)
	values (source.config_id, source.config_name, source.config_value);