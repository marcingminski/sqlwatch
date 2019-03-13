CREATE PROCEDURE [dbo].[usp_logger_index_usage_stats]
AS

declare @snapshot_time datetime = getdate();
declare @snapshot_type tinyint = 14
declare @database_name sysname
declare @sql varchar(max)

declare @object_id int
declare @index_name sysname
declare @index_id int
declare @object_name nvarchar(256)

set nocount on ;

/* step 1, get indexes from each database.
   we're creating snapshot timestamp here and because index collection may take few minutes,
   the timepstamp will not be 100% accureate but it does not matter much in this instance as
   we're not collecting very frequently and it will be enough to provide a common time anchor,
   to more accurately reflect the time when the index was collected we have [collection_time] */
insert into [dbo].[sql_perf_mon_snapshot_header]
values (@snapshot_time, @snapshot_type)

/* step 1 , collect indexes from all databases */
declare c_db cursor for
select [name] from sys.databases
where database_id > 4 and state_desc = 'ONLINE'
and [name] not like '%ReportingServer%'

open c_db

fetch next from c_db
into @database_name

while @@FETCH_STATUS = 0
	begin

		set @sql = 'insert into [dbo].[logger_index_usage_stats] (
	database_name, database_create_date, object_name, index_id, index_name, [used_pages_count],index_type,
	user_seeks, user_scans, user_lookups, user_updates, last_user_seek, last_user_scan, last_user_lookup, last_user_update,
	stats_date, snapshot_time, snapshot_type_id, index_disabled
	)
			select 
				database_name=dbs.name,
				database_create_date=dbs.create_date,
				[object_name] = object_schema_name(ixus.object_id,dbs.database_id) + ''.'' + object_name(ixus.object_id,dbs.database_id),
				ix.[index_id],
				[index_name] = ix.[name],
				ps.[used_page_count],
				[index_type] = ix.[type],
				ixus.[user_seeks],
				ixus.[user_scans],
				ixus.[user_lookups],
				ixus.[user_updates],
				ixus.[last_user_seek],
				ixus.[last_user_scan],
				ixus.[last_user_lookup],
				ixus.[last_user_update],
				[stats_date]=STATS_DATE(ix.object_id, ix.index_id),
				[snapshot_time] = ''' + convert(varchar(23),@snapshot_time,121) + ''',
				[snapshot_type_id] = ' + convert(varchar(5),@snapshot_type) + ',
				[is_disabled]=ix.is_disabled
			from sys.dm_db_index_usage_stats ixus

			inner join sys.databases dbs
				on dbs.database_id = ixus.database_id
				and dbs.name = ''' + @database_name + '''

			inner join ' + quotename(@database_name) + '.sys.indexes ix 
				on ix.index_id = ixus.index_id
				and ix.object_id = ixus.object_id

			inner join ' + quotename(@database_name) + '.sys.dm_db_partition_stats ps 
				on  ps.[object_id] = ix.[object_id]
				and ps.[index_id] = ix.[index_id]

			inner join ' + quotename(@database_name) + '.sys.tables t 
				on t.[object_id] = ix.[object_id]

			inner join ' + quotename(@database_name) + '.sys.schemas s 
				on s.[schema_id] = t.[schema_id]
'
		--print @sql
		Print '[' + convert(varchar(23),getdate(),121) + '] Collecting index statistics for database: ' + @database_name
		exec (@sql)
		
		
	fetch next from c_db
	into @database_name

	end
close c_db
deallocate c_db


/* step 2, collect index statistsics and histograms for the newly collected indexes */
create table #stats (
	[database_name] sysname default 'fe92qw0fa_dummy',
	[object_name] sysname default 'fe92qw0fa_dummy',
	index_name sysname default 'fe92qw0fa_dummy',
	index_id int,
	RANGE_HI_KEY sql_variant,
	RANGE_ROWS sql_variant,
	EQ_ROWS sql_variant,
	DISTINCT_RANGE_ROWS sql_variant,
	AVG_RANGE_ROWS sql_variant,
	[collection_time] datetime
)


set @snapshot_type = 15

declare c_index cursor for
select [database_name], table_name=object_name , index_name, index_id 
from [dbo].[logger_index_usage_stats]
where [snapshot_time] = @snapshot_time

open c_index

fetch next from c_index
into @database_name, @object_name, @index_name, @index_id

while @@FETCH_STATUS = 0
	begin
		--set @object_name = object_schema_name(@object_id) + '.' + object_name(@object_id)
		set @sql = 'use [' + @database_name + ']; 
dbcc show_statistics (''' + @object_name + ''',''' + @index_name + ''') with  HISTOGRAM'
		Print '[' + convert(varchar(23),getdate(),121) + '] Collecting index histogram for idnex: ' + @index_name

		insert into #stats (RANGE_HI_KEY,RANGE_ROWS,EQ_ROWS,DISTINCT_RANGE_ROWS,AVG_RANGE_ROWS)
		exec (@sql)
		--print 'Getting stats for: ' + @database_name

		update #stats
			set [database_name] = @database_name
				, [object_name] = @object_name
				, index_name = @index_name
				, index_id = @index_id
				, [collection_time] = getdate()
		where index_name = 'fe92qw0fa_dummy'

		fetch next from c_index
		into @database_name, @object_name, @index_name, @index_id
	end

close c_index
deallocate c_index 

	insert into [dbo].[sql_perf_mon_snapshot_header]
	values (@snapshot_time, @snapshot_type)

	insert into [dbo].[logger_index_stats_histogram](
		 [database_name], [database_create_date], 
		[object_name], [index_name], [index_id], 
		RANGE_HI_KEY, RANGE_ROWS, EQ_ROWS, DISTINCT_RANGE_ROWS, AVG_RANGE_ROWS,
		[snapshot_time], [snapshot_type_id], [collection_time])
	select
		dbs.[name],
		dbs.[create_date],
		st.[object_name],
		st.[index_name],
		st.[index_id],
		st.RANGE_HI_KEY,
		RANGE_ROWS = convert(real,st.RANGE_ROWS),
		EQ_ROWS = convert(real,st.EQ_ROWS),
		DISTINCT_RANGE_ROWS = convert(real,st.DISTINCT_RANGE_ROWS),
		AVG_RANGE_ROWS = convert(real,st.AVG_RANGE_ROWS),
		[snapshot_time] = @snapshot_time,
		[snapshot_type_id] = @snapshot_type,
		[collection_time]
	from #stats st
	inner join sys.databases dbs
		on dbs.[name] = st.[database_name]





