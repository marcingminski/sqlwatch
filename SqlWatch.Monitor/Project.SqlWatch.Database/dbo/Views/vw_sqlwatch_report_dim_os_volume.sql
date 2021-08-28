CREATE VIEW [dbo].[vw_sqlwatch_report_dim_os_volume] with schemabinding
	AS 
	with cte_volume as (
		select d.[sql_instance], d.[sqlwatch_volume_id], d.[volume_name], d.[label], d.[file_system], d.[volume_block_size_bytes], d.[date_created], d.[date_last_seen] 
		, volume_total_space_bytes_current = lg.[volume_total_space_bytes]
		, volume_free_space_bytes_current = lg.[volume_free_space_bytes]

		, volume_bytes_growth = fg.[volume_free_space_bytes] - lg.[volume_free_space_bytes]
		, total_growth_days = datediff(day,fg.snapshot_time,lg.snapshot_time)

		, [free_space_percentage] = lg.[volume_free_space_bytes] * 1.0 / lg.[volume_total_space_bytes]
		, [is_record_deleted]
		from dbo.sqlwatch_meta_os_volume d

		-- get first and last snapshot dates
		left join (
			select [sql_instance], [sqlwatch_volume_id],
				first_snapshot_time=min(snapshot_time),
				last_snapshot_time=max(snapshot_time)
			from [dbo].[sqlwatch_logger_disk_utilisation_volume]
			group by [sql_instance], [sqlwatch_volume_id]
		) h
		on h.sql_instance = d.sql_instance
		and h.sqlwatch_volume_id = d.sqlwatch_volume_id

		-- get first snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_volume] fg
		on h.[sql_instance] = fg.[sql_instance]
		and h.[sqlwatch_volume_id] = fg.[sqlwatch_volume_id]
		and h.first_snapshot_time = fg.snapshot_time

		-- get last snapshot data
		left join [dbo].[sqlwatch_logger_disk_utilisation_volume] lg
		on h.[sql_instance] = lg.[sql_instance]
		and h.[sqlwatch_volume_id] = lg.[sqlwatch_volume_id]
		and h.last_snapshot_time = lg.snapshot_time
		
), cte_volume_growth as (
	select [sql_instance], [sqlwatch_volume_id], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_created], [date_last_seen]
	, [volume_total_space_bytes_current], [volume_free_space_bytes_current], volume_bytes_growth, [total_growth_days]

	, growth_bytes_per_day = case when [total_growth_days] > 0 and volume_bytes_growth > 0 then [volume_bytes_growth] / [total_growth_days] else 0 end
	, days_until_full = case when [total_growth_days] > 0 and volume_bytes_growth > 0 then volume_free_space_bytes_current / ([volume_bytes_growth] / [total_growth_days]) else 9999 end
	, [free_space_percentage]
	, [is_record_deleted]
	from cte_volume
	)
	select [sql_instance], [sqlwatch_volume_id], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_created], [date_last_seen]
		, [volume_total_space_bytes_current], [volume_free_space_bytes_current], [volume_bytes_growth], [total_growth_days], [free_space_percentage]
		, [growth_bytes_per_day], [days_until_full], [is_record_deleted]
	, [total_space_formatted] = [dbo].[ufn_sqlwatch_format_bytes] ( volume_total_space_bytes_current )
	, [free_space_formatted] = [dbo].[ufn_sqlwatch_format_bytes] ( [volume_free_space_bytes_current] )
	, [growth_bytes_per_day_formatted] = [dbo].[ufn_sqlwatch_format_bytes] ( growth_bytes_per_day ) + ' /Day'
	, [free_space_percentage_formatted] = convert(varchar(50),convert(decimal(10,0),volume_free_space_bytes_current * 1.0 / volume_total_space_bytes_current  * 100.0)) + ' %'
	from cte_volume_growth;