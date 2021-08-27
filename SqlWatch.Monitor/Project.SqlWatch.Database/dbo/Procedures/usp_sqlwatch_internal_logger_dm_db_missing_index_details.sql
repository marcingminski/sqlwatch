CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_dm_db_missing_index_details]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as
begin
		set nocount on;

		exec [dbo].[usp_sqlwatch_internal_meta_add_index_missing]
			@xdoc = @xdoc,
			@sql_instance = @sql_instance;

		select 
			[last_user_seek]
			, [unique_compiles]
			, [user_seeks]
			, [user_scans]
			, [avg_total_user_cost]
			, [avg_user_impact]
			, [database_name]
			, [database_create_date]
			, [table_name]
			, [index_handle]
			, [equality_columns]
		into #t
		from openxml (@xdoc, '/CollectionSnapshot/missing_index_stats/row',1) 
			with (
				[last_user_seek] datetime2(3),
				[unique_compiles] bigint, 
				[user_seeks] bigint, 
				[user_scans] bigint, 
				[avg_total_user_cost] float, 
				[avg_user_impact] float,
				[database_name] nvarchar(128),
				database_create_date datetime2(3),
				table_name nvarchar(512),
				index_handle int,
				equality_columns nvarchar(4000)
			);
    
		insert into [dbo].[sqlwatch_logger_dm_db_missing_index_details] ([sqlwatch_database_id],
			[sqlwatch_table_id], [sqlwatch_missing_index_id],[snapshot_time], [last_user_seek], [unique_compiles],
			[user_seeks], [user_scans], [avg_total_user_cost], [avg_user_impact], [snapshot_type_id],[sql_instance])

		select 
			[sqlwatch_database_id] = db.[sqlwatch_database_id], 
			[sqlwatch_table_id] = mt.[sqlwatch_table_id],
			[sqlwatch_missing_index_id] = mii.sqlwatch_missing_index_id,
			[snapshot_time] = @snapshot_time,
			t.[last_user_seek],
			t.[unique_compiles], 
			t.[user_seeks], 
			t.[user_scans], 
			t.[avg_total_user_cost], 
			t.[avg_user_impact],
			[snapshot_type_id] = @snapshot_type_id,
			sql_instance = @sql_instance
		from #t t

			inner join [dbo].[sqlwatch_meta_database] db
				on db.[database_name] = t.[database_name] collate database_default
				and db.[database_create_date] = t.database_create_date
				and db.sql_instance = @sql_instance

			inner join [dbo].[sqlwatch_meta_table] mt
				on mt.sql_instance = db.sql_instance
				and mt.sqlwatch_database_id = db.sqlwatch_database_id
				and mt.table_name = t.table_name

			inner join [dbo].[sqlwatch_meta_index_missing] mii
				on mii.sqlwatch_database_id = db.sqlwatch_database_id
				and mii.sqlwatch_table_id = mt.sqlwatch_table_id
				and mii.sql_instance = mt.sql_instance
				and mii.index_handle = t.index_handle
				and mii.equality_columns = t.equality_columns collate database_default

		where t.equality_columns is not null;
end;