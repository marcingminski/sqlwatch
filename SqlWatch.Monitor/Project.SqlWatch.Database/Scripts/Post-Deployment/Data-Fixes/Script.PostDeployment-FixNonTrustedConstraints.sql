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



--the data validation part of the constraint (trusted,non-trusted) cannot be defined in visual studio
--as this is managed via deployment options but this does not seem to work for me in VS 2019.
--I am going to make all constraints trusted manually, hoping that VS will no revert back to non-trusted

--I hate doing this but not sure why VS fails to make them trusted?

Print 'Making Constraints Trusted Again'
set @sql = ''

select @sql = @sql + 'alter table ' + quotename(s.name) + '.' + quotename(o.name) + ' with check check constraint ' + quotename(i.name) + char(10)
from sys.foreign_keys i
inner join sys.objects o 
	on i.parent_object_id = o.object_id
inner join sys.schemas s
	on o.schema_id = s.schema_id
where i.is_not_trusted = 1
and i.is_not_for_replication = 0

exec (@sql)

set @sql = ''

select @sql = @sql + 'alter table ' + quotename(s.name) + '.' + quotename(t.name) + ' with check check constraint ' + quotename(c.name) + char(10)
from sys.tables t
inner join sys.schemas s
  on t.schema_id = s.schema_id
inner join sys.check_constraints c
  on t.object_id = c.parent_object_id
where c.is_not_trusted = 1