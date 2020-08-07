CREATE VIEW [dbo].[vw_sqlwatch_report_dim_table] with schemabinding
	AS 

	with cte_table as (
		select t.[sql_instance], t.[sqlwatch_database_id], t.[sqlwatch_table_id], [table_name], [table_type], [date_created], t.[date_last_seen], t.[is_record_deleted]
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

		outer apply (
			select [f].[sqlwatch_database_id], [f].[sqlwatch_table_id], [f].[row_count], [f].[total_pages], [f].[used_pages]
				 , [f].[data_compression], [f].[snapshot_type_id], [f].[snapshot_time], [f].[sql_instance], [f].[row_count_delta]
				 , [f].[total_pages_delta], [f].[used_pages_delta]

				 , h.first_snapshot_time, h.last_snapshot_time
			from [dbo].[sqlwatch_logger_disk_utilisation_table] f
			inner join (
				select sql_instance
					, snapshot_type_id
					, first_snapshot_time=min(snapshot_time)
					, last_snapshot_time=max(snapshot_time) 
				from [dbo].[sqlwatch_logger_snapshot_header]
				group by sql_instance, snapshot_type_id
			) h
				on h.sql_instance = f.sql_instance
				and h.snapshot_type_id = f.snapshot_type_id
				and h.last_snapshot_time = f.snapshot_time
			where f.sql_instance = t.sql_instance
			and f.sqlwatch_database_id = t.sqlwatch_database_id
			and f.sqlwatch_table_id = t.sqlwatch_table_id
		) vc

		outer apply (
			select [g1].[sqlwatch_database_id], [g1].[sqlwatch_table_id], [g1].[row_count], [g1].[total_pages], [g1].[used_pages], [g1].[data_compression], [g1].[snapshot_type_id], [g1].[snapshot_time], [g1].[sql_instance], [g1].[row_count_delta], [g1].[total_pages_delta], [g1].[used_pages_delta]
			from [dbo].[sqlwatch_logger_disk_utilisation_table] g1
			where g1.sql_instance = t.sql_instance
			and snapshot_time = vc.first_snapshot_time
			and g1.sqlwatch_database_id = vc.sqlwatch_database_id
			and g1.sqlwatch_table_id = vc.sqlwatch_table_id
			) fg

		outer apply (
			select [g2].[sqlwatch_database_id], [g2].[sqlwatch_table_id], [g2].[row_count], [g2].[total_pages], [g2].[used_pages], [g2].[data_compression], [g2].[snapshot_type_id], [g2].[snapshot_time], [g2].[sql_instance], [g2].[row_count_delta], [g2].[total_pages_delta], [g2].[used_pages_delta]
			from [dbo].[sqlwatch_logger_disk_utilisation_table] g2
			where g2.sql_instance = t.sql_instance
			and snapshot_time = vc.last_snapshot_time
			and g2.sqlwatch_database_id = vc.sqlwatch_database_id
			and g2.sqlwatch_table_id = vc.sqlwatch_table_id
			) lg

		where isnull(t.is_record_deleted,0) = 0

		), cte_table_growth as (
			select [sql_instance], [sqlwatch_database_id], [sqlwatch_table_id], [table_name], [table_type]
			, [date_created], [date_last_seen], [is_record_deleted], [total_growth_days]
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
			, [date_created]
			, [date_last_seen]
			, [is_record_deleted]
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
		from cte_table_growth