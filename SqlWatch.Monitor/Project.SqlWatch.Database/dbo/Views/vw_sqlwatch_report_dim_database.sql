CREATE VIEW [dbo].[vw_sqlwatch_report_dim_database] with schemabinding
as 
with cte_database as (
		select [database_name], [database_create_date], d.[sql_instance], d.[sqlwatch_database_id], [date_last_seen] 

		, [database_size_bytes_current] = lg.[database_size_bytes]
		, [database_bytes_growth] = lg.[database_size_bytes]  - fg.[database_size_bytes]
		, total_growth_days = datediff(day,fg.snapshot_time,lg.snapshot_time)
		, [log_size_total_bytes_current] = lg.[log_size_total_bytes]
		, [log_size_bytes_growth] = lg.[log_size_total_bytes] - fg.[log_size_total_bytes]

		, data_bytes_current = lg.data_bytes
		, index_size_bytes_current = lg.index_size_bytes
		, [unused_bytes_current] = lg.unused_bytes
		, unallocated_space_bytes_current = lg.unallocated_space_bytes

		from dbo.sqlwatch_meta_database d
		
		--calculate first and last snapshot dates
		left join (
			select sql_instance, sqlwatch_database_id,
				first_snapshot_time=min(snapshot_time),
				last_snapshot_time=max(snapshot_time)
			from [dbo].[sqlwatch_logger_disk_utilisation_database]
			group by sql_instance, sqlwatch_database_id
		) h
		on h.sql_instance = d.sql_instance
		and h.sqlwatch_database_id = d.sqlwatch_database_id

		--first snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_database] fg
		on h.first_snapshot_time = fg.snapshot_time
		and h.sqlwatch_database_id = fg.sqlwatch_database_id
		and h.sql_instance = fg.sql_instance

		--second snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_database] lg
		on h.last_snapshot_time = lg.snapshot_time
		and h.sqlwatch_database_id = lg.sqlwatch_database_id
		and h.sql_instance = lg.sql_instance

		where is_current = 1
), 

cte_database_growth as (
	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [date_last_seen]
		, [database_size_bytes_current], [database_bytes_growth], [total_growth_days] , [log_size_total_bytes_current], [log_size_bytes_growth]
		, database_growth_bytes_per_day = case when [total_growth_days] > 0 and [database_bytes_growth] > 0 then [database_bytes_growth] / total_growth_days else 0 end
		, log_growth_bytes_per_day = case when [total_growth_days] > 0 and [log_size_bytes_growth] > 0 then [log_size_bytes_growth] / total_growth_days else 0 end
		, data_bytes_current, index_size_bytes_current, [unused_bytes_current], unallocated_space_bytes_current
	from cte_database
)

	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [date_last_seen]
		, [database_size_bytes_current], [database_bytes_growth]
		, [total_growth_days], database_growth_bytes_per_day, log_growth_bytes_per_day, [log_size_total_bytes_current]
		, data_bytes_current, index_size_bytes_current, [unused_bytes_current], unallocated_space_bytes_current

		, last_seen_days = datediff(day,date_last_seen,getutcdate())

		, [database_size_bytes_current_formatted] =  [dbo].[ufn_sqlwatch_format_bytes] ([database_size_bytes_current])
		, [growth_bytes_per_day_formatted] = [dbo].[ufn_sqlwatch_format_bytes] (database_growth_bytes_per_day) + ' / Day'
		, [log_size_bytes_current_formatted] = [dbo].[ufn_sqlwatch_format_bytes] ([log_size_total_bytes_current])
		, [log_growth_bytes_per_day_formatted] = [dbo].[ufn_sqlwatch_format_bytes] (log_growth_bytes_per_day) + ' / Day'

	from cte_database_growth;