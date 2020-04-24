CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_index_usage_stats]
	@databases varchar(max) = '-tempdb',
	@ignore_global_exclusion bit = 0
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_logger_index_usage_stats

 Description:
	Collect index statistics.

 Parameters
	@databases		: list of databases to include exclude in Ola Hallengren format:
						include specific dbs: 'DB1,DB2,DB3, %DB%' 
						exclude specific dbs: '-DB1,-DB2'
	@ignore_global_exclusion		: whether to ignore exclusions in the config table [dbo].[sqlwatch_config_exclude_database]
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski, Initial version
	1.1		2019-12-05	- Marcin Gminski, Ability to exclude database from iteration altogether rather than just data collection.
							In some cases, trying to get index stats from tempdb may deadlock due to schema locks in tempdb.
							Excluding tempdb from iteration means the code will not even be executed there.
	1.2		2019-12-09	- Marcin Gminski, Fixed cartersian product #129
	1.3		2019-12-14	- Marcin Gminski, use usp_sqlwatch_internal_insert_header isntead of direct insert
	1.4		2020-03-18	- Marcin Gminski, move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
	1.5		2020-04-24	- Marcin Gminski, fixed transaction count error on failure.
-------------------------------------------------------------------------------------------------------------------
*/

set xact_abort on
set nocount on

declare @snapshot_time datetime2(0),
		@snapshot_type_id tinyint = 14,
		@database_name sysname,
		@sql varchar(max),
		@date_snapshot_previous datetime2(0),
		@object_id int,
		@index_name sysname,
		@index_id int,
		@object_name nvarchar(256)

select @date_snapshot_previous = max([snapshot_time])
	from [dbo].[sqlwatch_logger_snapshot_header] (nolock) --so we dont get blocked by central repository. this is safe at this point.
	where snapshot_type_id = @snapshot_type_id
	and sql_instance = @@SERVERNAME

	exec [dbo].[usp_sqlwatch_internal_insert_header] 
		@snapshot_time_new = @snapshot_time OUTPUT,
		@snapshot_type_id = @snapshot_type_id

/* step 2 , collect indexes from all databases */
		set @sql = 'insert into [dbo].[sqlwatch_logger_index_usage_stats] (
	sqlwatch_database_id, [sqlwatch_index_id], [used_pages_count],
	user_seeks, user_scans, user_lookups, user_updates, last_user_seek, last_user_scan, last_user_lookup, last_user_update,
	stats_date, snapshot_time, snapshot_type_id, index_disabled, partition_id, [sqlwatch_table_id],

	[used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds], [user_lookups_delta],
	[partition_count], [partition_count_delta]
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
				[snapshot_type_id] = ' + convert(varchar(5),@snapshot_type_id) + ',
				[is_disabled]=ix.is_disabled,
				partition_id = -1,
				mi.sqlwatch_table_id

				, [used_pages_count_delta] = case when ps.[used_page_count] > usprev.[used_pages_count] then ps.[used_page_count] - usprev.[used_pages_count] else 0 end
				, [user_seeks_delta] = case when ixus.[user_seeks] > usprev.[user_seeks] then ixus.[user_seeks] - usprev.[user_seeks] else 0 end
				, [user_scans_delta] = case when ixus.[user_scans] > usprev.[user_scans] then ixus.[user_scans] - usprev.[user_scans] else 0 end
				, [user_updates_delta] = case when ixus.[user_updates] > usprev.[user_updates] then ixus.[user_updates] - usprev.[user_updates] else 0 end
				, [delta_seconds_delta] = datediff(second,''' + convert(varchar(23),@date_snapshot_previous,121) + ''',''' + convert(varchar(23),@snapshot_time,121) + ''')
				, [user_lookups_delta] = case when ixus.[user_lookups] > usprev.[user_lookups] then ixus.[user_lookups] - usprev.[user_lookups] else 0 end
				, [partition_count] = ps.partition_count
				, [partition_count_delta] = usprev.partition_count - ps.partition_count
			from sys.dm_db_index_usage_stats ixus

			inner join sys.databases dbs
				on dbs.database_id = ixus.database_id
				and dbs.name = ''?''

			inner join [?].sys.indexes ix 
				on ix.index_id = ixus.index_id
				and ix.object_id = ixus.object_id

			/*	to reduce size of the index stats table, we are going to aggreagte partitions into tables.
				from daily database management and DBA point of view, we care more about overall index stats rather than
				individual partitions.	*/
			inner join (select [object_id], [index_id], [used_page_count]=sum([used_page_count]), [partition_count]=count(*)
				from [?].sys.dm_db_partition_stats
				group by [object_id], [index_id]
				) ps 
				on  ps.[object_id] = ix.[object_id]
				and ps.[index_id] = ix.[index_id]

			inner join [?].sys.tables t 
				on t.[object_id] = ix.[object_id]

			inner join [?].sys.schemas s 
				on s.[schema_id] = t.[schema_id]

			inner join [dbo].[sqlwatch_meta_database] mdb
				on mdb.database_name = dbs.name collate database_default
				and mdb.database_create_date = dbs.create_date

			/* https://github.com/marcingminski/sqlwatch/issues/110 */
			inner join [dbo].[sqlwatch_meta_table] mt
				on mt.sql_instance = mdb.sql_instance
				and mt.sqlwatch_database_id = mdb.sqlwatch_database_id
				and mt.table_name = s.name + ''.'' + t.name collate database_default

			inner join [dbo].[sqlwatch_meta_index] mi
				on mi.sql_instance = @@SERVERNAME
				and mi.sqlwatch_database_id = mdb.sqlwatch_database_id
				and mi.sqlwatch_table_id = mt.sqlwatch_table_id
				and mi.index_id = ixus.index_id
				and mi.index_name = case when mi.index_type_desc = ''HEAP'' then t.[name] else ix.[name] end collate database_default

			left join [dbo].[sqlwatch_logger_index_usage_stats] usprev
				on usprev.sql_instance = mi.sql_instance
				and usprev.sqlwatch_database_id = mi.sqlwatch_database_id
				and usprev.sqlwatch_table_id = mi.sqlwatch_table_id
				and usprev.sqlwatch_index_id = mi.sqlwatch_index_id
				and usprev.snapshot_type_id = ' + convert(varchar(5),@snapshot_type_id) + '
				and usprev.snapshot_time = ''' + convert(varchar(23),@date_snapshot_previous,121) + '''
				and usprev.partition_id = -1

			Print ''['' + convert(varchar(23),getdate(),121) + ''] Collecting index statistics for database: ?''
'

exec [dbo].[usp_sqlwatch_internal_foreachdb] 
	@command = @sql,
	@snapshot_type_id = @snapshot_type_id,
	@calling_proc_id = @@PROCID,
	@databases = @databases
