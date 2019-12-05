CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_index_usage_stats]
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_logger_index_usage_stats

 Description:
	Collect index statistics.

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski, Initial version
	1.1		2012-12-05	- Marcin Gminski, Ability to exclude database from iteration altogether rather than just data collection.
							In some cases, trying to get index stats from tempdb may deadlock due to schema locks in tempdb.
							Excluding tempdb from iteration means the code will not even be executed there.
-------------------------------------------------------------------------------------------------------------------
*/

set xact_abort on
begin tran

declare @snapshot_time datetime = getutcdate();
declare @snapshot_type tinyint = 14
declare @database_name sysname
declare @sql varchar(max)
declare @date_snapshot_previous datetime

declare @object_id int
declare @index_name sysname
declare @index_id int
declare @object_name nvarchar(256)

set nocount on ;

select @date_snapshot_previous = max([snapshot_time])
	from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
	where snapshot_type_id = @snapshot_type
	and sql_instance = @@SERVERNAME


/* step 1, get indexes from each database.
   we're creating snapshot timestamp here and because index collection may take few minutes,
   the timepstamp will not be 100% accureate but it does not matter much in this instance as
   we're not collecting very frequently and it will be enough to provide a common time anchor,
   to more accurately reflect the time when the index was collected we have [collection_time] */
insert into [dbo].[sqlwatch_logger_snapshot_header] (snapshot_time, snapshot_type_id)
values (@snapshot_time, @snapshot_type)

/* step 2 , collect indexes from all databases */
		set @sql = 'insert into [dbo].[sqlwatch_logger_index_usage_stats] (
	sqlwatch_database_id, [sqlwatch_index_id], [used_pages_count],
	user_seeks, user_scans, user_lookups, user_updates, last_user_seek, last_user_scan, last_user_lookup, last_user_update,
	stats_date, snapshot_time, snapshot_type_id, index_disabled, partition_id, [sqlwatch_table_id],

	[used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds], [user_lookups_delta]
	)
			select 
				mi.sqlwatch_database_id,
				mi.[sqlwatch_index_id],
				[used_page_count] = convert(real,ps.[used_page_count]),
				[user_seeks] = convert(real,ixus.[user_seeks]),
				[user_scans] = convert(real,ixus.[user_scans]),
				[user_lookups] = convert(real,ixus.[user_lookups]),
				[user_updates] = convert(real,ixus.[user_updates]),
				ixus.[last_user_seek],
				ixus.[last_user_scan],
				ixus.[last_user_lookup],
				ixus.[last_user_update],
				[stats_date]=STATS_DATE(ix.object_id, ix.index_id),
				[snapshot_time] = ''' + convert(varchar(23),@snapshot_time,121) + ''',
				[snapshot_type_id] = ' + convert(varchar(5),@snapshot_type) + ',
				[is_disabled]=ix.is_disabled,
				ps.partition_id,
				mi.sqlwatch_table_id

				, [used_pages_count_delta] = case when ps.[used_page_count] > usprev.[used_pages_count] then ps.[used_page_count] - usprev.[used_pages_count] else 0 end
				, [user_seeks_delta] = case when ixus.[user_seeks] > usprev.[user_seeks] then ixus.[user_seeks] - usprev.[user_seeks] else 0 end
				, [user_scans_delta] = case when ixus.[user_scans] > usprev.[user_scans] then ixus.[user_scans] - usprev.[user_scans] else 0 end
				, [user_updates_delta] = case when ixus.[user_updates] > usprev.[user_updates] then ixus.[user_updates] - usprev.[user_updates] else 0 end
				, [delta_seconds_delta] = datediff(second,''' + convert(varchar(23),@date_snapshot_previous,121) + ''',''' + convert(varchar(23),@snapshot_time,121) + ''')
				, [user_lookups_delta] = case when ixus.[user_lookups] > usprev.[user_lookups] then ixus.[user_lookups] - usprev.[user_lookups] else 0 end
			from sys.dm_db_index_usage_stats ixus

			inner join sys.databases dbs
				on dbs.database_id = ixus.database_id
				and dbs.name = ''?''

			inner join [?].sys.indexes ix 
				on ix.index_id = ixus.index_id
				and ix.object_id = ixus.object_id

			inner join [?].sys.dm_db_partition_stats ps 
				on  ps.[object_id] = ix.[object_id]
				and ps.[index_id] = ix.[index_id]

			inner join [?].sys.tables t 
				on t.[object_id] = ix.[object_id]

			inner join [?].sys.schemas s 
				on s.[schema_id] = t.[schema_id]

			inner join [dbo].[sqlwatch_meta_index] mi
				on mi.sql_instance = @@SERVERNAME
				and mi.sqlwatch_database_id = mi.sqlwatch_database_id
				and mi.sqlwatch_table_id = mi.sqlwatch_table_id

			inner join [dbo].[sqlwatch_meta_database] mdb
				on mdb.sqlwatch_database_id = mi.sqlwatch_database_id
				and mdb.database_name = dbs.name collate database_default
				and mdb.database_create_date = dbs.create_date

			/* https://github.com/marcingminski/sqlwatch/issues/110 */
			inner join [dbo].[sqlwatch_meta_table] mt
				on mt.sql_instance = mdb.sql_instance
				and mt.sqlwatch_database_id = mdb.sqlwatch_database_id
				and mt.table_name = s.name + ''.'' + t.name collate database_default

			left join [dbo].[sqlwatch_logger_index_usage_stats] usprev
				on usprev.sql_instance = mi.sql_instance
				and usprev.sqlwatch_database_id = mi.sqlwatch_database_id
				and usprev.sqlwatch_table_id = mi.sqlwatch_table_id
				and usprev.sqlwatch_index_id = mi.sqlwatch_index_id
				and usprev.snapshot_type_id = ' + convert(varchar(5),@snapshot_type) + '
				and usprev.snapshot_time = ''' + convert(varchar(23),@date_snapshot_previous,121) + '''
				and usprev.partition_id = ps.partition_id

			Print ''['' + convert(varchar(23),getdate(),121) + ''] Collecting index statistics for database: ?''
'
exec [dbo].[usp_sqlwatch_internal_foreachdb] @command = @sql, @snapshot_type_id = @snapshot_type

commit tran