CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_disk_utilisation_table]
	@debug bit = 0 
as


declare @sql nvarchar(max),
		@sqlwatchdb nvarchar(128) = DB_NAME(),
		@snapshot_type_id tinyint = 22,
		@snapshot_time datetime2(0),
		@previous_snapshot_time datetime2(0)

	select @previous_snapshot_time = max(snapshot_time)
	from dbo.sqlwatch_logger_snapshot_header
	where sql_instance = @@SERVERNAME
	and snapshot_type_id = @snapshot_type_id

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id

set @sql = '
set transaction isolation level read uncommitted
insert into ' + quotename(@sqlwatchdb) + '.[dbo].[sqlwatch_logger_disk_utilisation_table](
	  sqlwatch_database_id
	, sqlwatch_table_id
	, row_count
	, total_pages
	, used_pages
	, data_compression
	, snapshot_type_id
	, snapshot_time
	, sql_instance
	, row_count_delta
	, total_pages_delta
	, used_pages_delta
	)
select 
	mt.sqlwatch_database_id,
	mt.sqlwatch_table_id,
	row_count = convert(real,avg(p.rows)),
	total_pages = convert(real,sum(a.total_pages)),
	used_pages = convert(real,sum(a.used_pages)),
	p.[data_compression],
	' + convert(varchar(10),@snapshot_type_id) + ',
	''' + convert(varchar(23),@snapshot_time,121) + ''',
	@@SERVERNAME,
	row_count_delta = convert(real,isnull(avg(p.rows) - max(dt.row_count),0)),
	total_pages_delta = convert(real,isnull(sum(a.total_pages) - max(dt.total_pages),0)),
	used_pages_delta = convert(real,isnull(sum(a.used_pages) - max(dt.used_pages),0))
from [?].sys.tables t
inner join [?].sys.indexes i on t.object_id = i.object_id
inner join [?].sys.partitions p on i.object_id = p.object_id AND i.index_id = p.index_id
inner join [?].sys.allocation_units a on p.partition_id = a.container_id
inner join [?].sys.schemas s on t.schema_id = s.schema_id
inner join sys.databases sdb on sdb.name = ''?''

inner join ' + quotename(@sqlwatchdb) + '.[dbo].[sqlwatch_meta_database] mdb
	on mdb.database_name = sdb.name collate database_default
	and mdb.database_create_date = sdb.create_date
	and mdb.sql_instance = @@SERVERNAME

inner join ' + quotename(@sqlwatchdb) + '.[dbo].[sqlwatch_meta_table] mt
	on mt.table_name = s.name + ''.'' + t.name collate database_default
	and mt.sqlwatch_database_id = mdb.sqlwatch_database_id
	and mt.sql_instance = mdb.sql_instance

left join ' + quotename(@sqlwatchdb) + '.[dbo].[sqlwatch_logger_disk_utilisation_table] dt
	on dt.sqlwatch_database_id = mdb.sqlwatch_database_id
	and dt.sql_instance = mdb.sql_instance
	and dt.sqlwatch_table_id = mt.sqlwatch_table_id
	and dt.snapshot_time = ''' + convert(varchar(23),@previous_snapshot_time,121) + '''

group by mt.sqlwatch_database_id, mt.sqlwatch_table_id, p.[data_compression]'

exec [dbo].[usp_sqlwatch_internal_foreachdb] @command = @sql, @snapshot_type_id = @snapshot_type_id, @debug = @debug