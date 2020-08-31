CREATE PROCEDURE [dbo].[usp_sqlwatch_purge_orphaned_snapshots]
as

declare @sql varchar(max) = ''

select @sql = @sql + 'delete l from ' + TABLE_NAME + ' l
left join [dbo].[sqlwatch_logger_snapshot_header] h
on h.sql_instance = l.sql_instance
and h.snapshot_type_id = l.snapshot_type_id
and h.snapshot_time = l.snapshot_time
where h.snapshot_time is null;'
from INFORMATION_SCHEMA.TABLES
where TABLE_NAME like '%logger%'
and TABLE_TYPE = 'BASE TABLE'

exec (@sql)

