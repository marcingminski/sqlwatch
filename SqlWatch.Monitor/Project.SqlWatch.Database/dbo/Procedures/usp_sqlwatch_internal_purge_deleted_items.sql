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
and ' + COLUMN_NAME + ' is not null
set @rows_affected = @@ROWCOUNT

Print ''Purged '' + convert(varchar(10),@rows_affected) + '' rows from ' + TABLE_SCHEMA + '.' + TABLE_NAME + ' ''
'
 from INFORMATION_SCHEMA.COLUMNS
/*	I should have been more careful when naming columns, I ended up having all these variations.
	The exception is base_object_date_last_seen which is different to date_last_seen as it referes to a parent object rather than row in the actual table */
WHERE (
	COLUMN_NAME in ('deleted_when', 'date_deleted', 'last_seen','last_seen_date','date_last_seen')
	AND TABLE_NAME LIKE 'sqlwatch_meta%'
	)
OR
	(
	COLUMN_NAME in ('base_object_date_last_seen')
	AND TABLE_NAME = 'sqlwatch_config_check'
	);

set nocount on;

exec (@sql);