CREATE VIEW [dbo].[vw_sqlwatch_report_dim_table] with schemabinding
	AS 

	with cte_table as (
		select t.[sql_instance], t.[sqlwatch_database_id], t.[sqlwatch_table_id], [table_name], [table_type], [date_first_seen], t.[date_last_seen]
		, used_pages_growth = lg.used_pages  - fg.used_pages
		, row_count_growth = lg.[row_count] - fg.[row_count]
		, total_growth_days = datediff(day,fg.snapshot_time,lg.snapshot_time)
		, last_snapshot_time=lg.snapshot_time
		, used_pages_current = lg.used_pages
		, row_count_current = lg.row_count
		, db.[database_name]
		, lg.data_compression
		from dbo.sqlwatch_meta_table t

		inner join dbo.sqlwatch_meta_database db
			on db.sqlwatch_database_id = t.sqlwatch_database_id
			and db.sql_instance = t.sql_instance
			and db.is_current = 1

		-- get first and last snapshot dates
		left join (
			select [sql_instance], sqlwatch_database_id, sqlwatch_table_id
					, first_snapshot_time=min(snapshot_time)
					, last_snapshot_time=max(snapshot_time) 
			from [dbo].[sqlwatch_logger_disk_utilisation_table] 
			group by [sql_instance], sqlwatch_database_id, sqlwatch_table_id
		) h
		on h.sql_instance = t.sql_instance
		and h.sqlwatch_database_id = t.sqlwatch_database_id
		and h.sqlwatch_table_id = t.sqlwatch_table_id

		-- get first snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_table]  fg
		on fg.sql_instance = h.sql_instance
		and fg.sqlwatch_database_id = h.sqlwatch_database_id
		and fg.sqlwatch_table_id = h.sqlwatch_table_id
		and fg.snapshot_time = h.first_snapshot_time

		-- get last snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_table]  lg
		on lg.sql_instance = h.sql_instance
		and lg.sqlwatch_database_id = h.sqlwatch_database_id
		and lg.sqlwatch_table_id = h.sqlwatch_table_id
		and lg.snapshot_time = h.last_snapshot_time
), 
	cte_table_growth as (
			select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [table_name], [table_type]
			, [date_first_seen], [date_last_seen], [total_growth_days]
			, [used_pages_growth_per_day] = case when [total_growth_days] > 0 and used_pages_growth > 0 then used_pages_growth / total_growth_days else 0 end
			, [row_count_growth_per_day] = case when [total_growth_days] > 0 and row_count_growth > 0 then row_count_growth / total_growth_days else 0 end
			, last_snapshot_time,used_pages_current,row_count_current, [database_name], data_compression
			from cte_table
		)
		select 
			  [sql_instance]
			, [sqlwatch_database_id]
			, [database_name]
			, [sqlwatch_table_id]
			, [table_name]
			, [table_type]
			, [date_first_seen]
			, [date_last_seen]
			, used_pages_current 
			/* 1 page is 8KB but the function expects bytes */
			, used_bytes_current_formatted = [dbo].[ufn_sqlwatch_format_bytes] (used_pages_current * 1024.00 * 8.00)
			, growth_bytes_per_day_formatted = [dbo].[ufn_sqlwatch_format_bytes] ([used_pages_growth_per_day] * 1024.00 * 8.00) + ' / Day'

			, row_count_current
			, [row_count_growth_per_day]
			, [used_pages_growth_per_day]
			, last_snapshot_time
			, data_compression = case data_compression
when 0 then 'NONE'
when 1 then 'ROW'
when 2 then 'PAGE'
when 3 then 'COLUMNSTORE : Applies to: SQL Server 2012 (11.x) and later'
when 4 then 'COLUMNSTORE_ARCHIVE : Applies to: SQL Server 2014 (12.x) and later'
else 'UNKNOWN' end
		from cte_table_growth;