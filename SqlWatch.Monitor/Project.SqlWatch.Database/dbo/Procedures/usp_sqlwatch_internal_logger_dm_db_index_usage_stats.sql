CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_db_index_usage_stats]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
AS
begin

	set nocount on;

	exec [dbo].[usp_sqlwatch_internal_meta_add_index]
		@xdoc = @xdoc,
		@sql_instance = @sql_instance;

	select [t].[used_page_count], [t].[user_seeks], [t].[user_scans], [t].[user_lookups], [t].[user_updates], [t].[last_user_seek], [t].[last_user_scan], [t].[last_user_lookup]
		, [t].[last_user_update], [t].[stats_date], [t].[is_disabled], [t].[partition_id], [t].[partition_count], [t].[database_name], [t].[database_create_date], [t].[table_name]
		, [t].[index_name], [t].[index_id]
		, mdb.sqlwatch_database_id
		, mt.sqlwatch_table_id
		, mi.sqlwatch_index_id
		, mi.[last_usage_stats_snapshot_time]
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/index_usage_stats/row',1) 
		with (
			used_page_count real,
			user_seeks real,
			user_scans real,
			user_lookups real,
			user_updates real,
			last_user_seek datetime2(3),
			last_user_scan datetime2(3),
			last_user_lookup datetime2(3),
			last_user_update datetime2(3),
			stats_date datetime2(3),
			is_disabled bit,
			partition_id bigint,
			partition_count bigint,
			database_name nvarchar(128),
			database_create_date datetime2(3),
			table_name nvarchar(512),
			index_name nvarchar(512),
			index_id int
		) t

		inner join [dbo].[sqlwatch_meta_database] mdb
			on mdb.database_name = t.database_name collate database_default
			and mdb.database_create_date = t.database_create_date
			and mdb.sql_instance = @sql_instance

		inner join [dbo].[sqlwatch_meta_table] mt
			on mt.sql_instance = @sql_instance
			and mt.sqlwatch_database_id = mdb.sqlwatch_database_id
			and mt.table_name = t.table_name collate database_default

		inner join [dbo].[sqlwatch_meta_index] mi
			on mi.sql_instance = @sql_instance
			and mi.sqlwatch_database_id = mdb.sqlwatch_database_id
			and mi.sqlwatch_table_id = mt.sqlwatch_table_id
			and mi.index_id = t.index_id
			and mi.index_name = t.index_name collate database_default

			;

	insert into [dbo].[sqlwatch_logger_dm_db_index_usage_stats] (
			sqlwatch_database_id, [sqlwatch_index_id], [used_pages_count],
			user_seeks, user_scans, user_lookups, user_updates, last_user_seek, last_user_scan, last_user_lookup, last_user_update,
			stats_date, snapshot_time, snapshot_type_id, index_disabled, partition_id, [sqlwatch_table_id],

			[used_pages_count_delta], [user_seeks_delta], [user_scans_delta], [user_updates_delta], [delta_seconds], [user_lookups_delta],
			[partition_count], [partition_count_delta],
			[sql_instance]
			)
		select 
			t.sqlwatch_database_id,
			t.[sqlwatch_index_id],
			t.[used_page_count],
			t.[user_seeks],
			t.[user_scans],
			t.[user_lookups],
			t.[user_updates] ,
			t.[last_user_seek],
			t.[last_user_scan],
			t.[last_user_lookup],
			t.[last_user_update],
			t.[stats_date],
			[snapshot_time] = @snapshot_time,
			[snapshot_type_id] = @snapshot_type_id,
			t.[is_disabled],
			t.partition_id,
			t.sqlwatch_table_id

			, [used_pages_count_delta] = case when t.[used_page_count] > usprev.[used_pages_count] then t.[used_page_count] - usprev.[used_pages_count] else 0 end
			, [user_seeks_delta] = case when t.[user_seeks] > usprev.[user_seeks] then t.[user_seeks] - usprev.[user_seeks] else 0 end
			, [user_scans_delta] = case when t.[user_scans] > usprev.[user_scans] then t.[user_scans] - usprev.[user_scans] else 0 end
			, [user_updates_delta] = case when t.[user_updates] > usprev.[user_updates] then t.[user_updates] - usprev.[user_updates] else 0 end
			, [delta_seconds_delta] = datediff(second,usprev.snapshot_time,@snapshot_time)
			, [user_lookups_delta] = case when t.[user_lookups] > usprev.[user_lookups] then t.[user_lookups] - usprev.[user_lookups] else 0 end
			, [partition_count] = t.partition_count
			, [partition_count_delta] = usprev.partition_count - t.partition_count

			, [sql_instance] = @sql_instance
		from #t t

		left join [dbo].[sqlwatch_logger_dm_db_index_usage_stats] usprev
			on usprev.sql_instance = @sql_instance
			and usprev.sqlwatch_database_id = t.sqlwatch_database_id
			and usprev.sqlwatch_table_id = t.sqlwatch_table_id
			and usprev.sqlwatch_index_id = t.sqlwatch_index_id
			and usprev.snapshot_type_id = @snapshot_type_id
			and usprev.snapshot_time = t.[last_usage_stats_snapshot_time]
			and usprev.partition_id = -1;

		update m
			set [last_usage_stats_snapshot_time] = @snapshot_time
		from [dbo].[sqlwatch_meta_index] m
		inner join #t t
		on m.sql_instance = @sql_instance
		and m.sqlwatch_database_id = t.sqlwatch_database_id
		and m.sqlwatch_table_id = t.sqlwatch_table_id
		and m.sqlwatch_index_id = t.sqlwatch_index_id;

end;