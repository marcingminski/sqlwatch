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

--------------------------------------------------------------------------------------
-- set baseline for empty last_seen dates (when upgrading from previous versions)
--------------------------------------------------------------------------------------
declare @sql varchar(max)

set @sql = ''

select @sql = @sql + '
update ' + TABLE_SCHEMA + '.' + TABLE_NAME + '
set [' + COLUMN_NAME + '] = GETUTCDATE()
where [' + COLUMN_NAME + '] is null
'
 from INFORMATION_SCHEMA.COLUMNS
/*	I should have been more careful when naming columns, I ended up having all these variations.
	Yes, I know....*/
WHERE COLUMN_NAME in ('deleted_when', 'date_deleted', 'last_seen','last_seen_date','date_last_seen')
AND TABLE_NAME LIKE 'sqlwatch_meta%'


exec (@sql)