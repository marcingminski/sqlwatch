CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_purge_deleted_items]
as
declare @sql varchar(max),
		@purge_after_days tinyint,
		@row_batch_size int

set @purge_after_days = [dbo].[ufn_sqlwatch_get_config_value]  (2, null)
set @row_batch_size = [dbo].[ufn_sqlwatch_get_config_value]  (5, null)
set @sql = 'declare @rows_affected bigint'

select @sql = @sql + '
delete top (' + convert(varchar(10),@row_batch_size) + ') from ' + TABLE_SCHEMA + '.' + TABLE_NAME + '
where ' + COLUMN_NAME + ' < dateadd(day,-' + convert(varchar(10),@purge_after_days) +',getutcdate())
set @rows_affected = @@ROWCOUNT

Print ''Purged '' + convert(varchar(10),@rows_affected) + '' rows from ' + TABLE_SCHEMA + '.' + TABLE_NAME + ' ''
'
 from INFORMATION_SCHEMA.COLUMNS
/*	I should have been more careful when naming columns, I ended up having all these variations.
	Yes, I know....*/
WHERE COLUMN_NAME in ('deleted_when', 'date_deleted', 'last_seen','last_seen_date','date_last_seen')
AND TABLE_NAME LIKE 'sqlwatch_meta%'

set nocount on

exec (@sql)