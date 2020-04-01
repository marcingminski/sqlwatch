CREATE PROCEDURE [dbo].[usp_sqlwatch_config_enable_compression_sqlwatch_tables]
as

declare @sql varchar(max)
set @sql = ''
select @sql = @sql + 'alter table ' + TABLE_SCHEMA + '.' + TABLE_NAME + ' rebuild partition = all with (data_compression = page);
' 
from INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%sqlwatch_%'
and TABLE_TYPE = 'BASE TABLE'

print @sql 
exec (@sql)

