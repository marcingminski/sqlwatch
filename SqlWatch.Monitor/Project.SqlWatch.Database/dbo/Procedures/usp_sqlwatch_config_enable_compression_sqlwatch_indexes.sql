CREATE PROCEDURE [dbo].[usp_sqlwatch_config_enable_compression_sqlwatch_indexes]
as

declare @sql varchar(max)
set @sql = ''

select @sql = @sql + 'alter index [' + idx.name +'] on ' + sh.name + '.' + tbl.name + ' rebuild partition = all with (data_compression = page);
'
from sys.indexes idx
inner join sys.tables tbl
	on tbl.object_id = idx.object_id
inner join sys.schemas sh
	on tbl.schema_id = sh.schema_id
where tbl.name like 'sqlwatch%'
and idx.name is not null

print @sql
exec (@sql)