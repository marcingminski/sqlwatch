CREATE VIEW [dbo].[vw_sqlwatch_report_dim_os_volume] with schemabinding
	AS 

	with cte_volume as (
		select d.[sql_instance], d.[sqlwatch_volume_id], d.[volume_name], d.[label], d.[file_system], d.[volume_block_size_bytes], d.[date_added], d.[date_updated], d.[last_seen] 
		, volume_total_space_bytes_current = vc.[volume_total_space_bytes]
		, volume_free_space_bytes_current = vc.[volume_free_space_bytes]

		, volume_bytes_growth = fg.[volume_free_space_bytes] - lg.[volume_free_space_bytes]
		, total_growth_days = datediff(day,fg.snapshot_time,lg.snapshot_time)

		, [free_space_percentage] = vc.[volume_free_space_bytes] * 1.0 / vc.[volume_total_space_bytes]
		from dbo.sqlwatch_meta_os_volume d

		outer apply (
			select [f].[sqlwatch_volume_id], [f].[volume_free_space_bytes], [f].[volume_total_space_bytes], [f].[snapshot_time], [f].[snapshot_type_id], [f].[sql_instance]
			, h.first_snapshot_time, h.last_snapshot_time
			from [dbo].[sqlwatch_logger_disk_utilisation_volume] f
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
			where f.sql_instance = d.sql_instance
			and f.sqlwatch_volume_id = d.sqlwatch_volume_id
			) vc

		outer apply (
			select g1.[volume_free_space_bytes], g1.snapshot_time
			from [dbo].[sqlwatch_logger_disk_utilisation_volume] g1
			where g1.sql_instance = d.sql_instance
			and snapshot_time = vc.first_snapshot_time
			and g1.sqlwatch_volume_id = d.sqlwatch_volume_id
			) fg

		outer apply (
			select g2.volume_free_space_bytes, g2.snapshot_time
			from [dbo].[sqlwatch_logger_disk_utilisation_volume] g2
			where g2.sql_instance = d.sql_instance
			and snapshot_time = vc.last_snapshot_time
			and g2.sqlwatch_volume_id = d.sqlwatch_volume_id
			) lg
	), cte_volume_growth as (
	select [sql_instance], [sqlwatch_volume_id], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_added], [date_updated], [last_seen]
	, [volume_total_space_bytes_current], [volume_free_space_bytes_current], volume_bytes_growth, [total_growth_days]

	, growth_bytes_per_day = case when [total_growth_days] > 0 and volume_bytes_growth > 0 then [volume_bytes_growth] / [total_growth_days] else 0 end
	, days_until_full = case when [total_growth_days] > 0 and volume_bytes_growth > 0 then volume_free_space_bytes_current / ([volume_bytes_growth] / [total_growth_days]) else 0 end
	, [free_space_percentage]
	from cte_volume
	)
	select [sql_instance], [sqlwatch_volume_id], [volume_name], [label], [file_system], [volume_block_size_bytes], [date_added], [date_updated], [last_seen]
		, [volume_total_space_bytes_current], [volume_free_space_bytes_current], [volume_bytes_growth], [total_growth_days], [free_space_percentage]
		, [growth_bytes_per_day], [days_until_full]
	, [total_space_formatted] = case 
			when volume_total_space_bytes_current / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),volume_total_space_bytes_current / 1024.0 )) + ' KB'
			when volume_total_space_bytes_current / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),volume_total_space_bytes_current / 1024.0 / 1024.0)) + ' MB'
			when volume_total_space_bytes_current / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),volume_total_space_bytes_current / 1024.0 / 1024.0 / 1024.0)) + ' GB' 
			else convert(varchar(100),convert(decimal(5,2),volume_total_space_bytes_current / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end
	, [free_space_formatted] = case
			when [volume_free_space_bytes_current] / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),[volume_free_space_bytes_current] / 1024.0 )) + ' KB'
			when [volume_free_space_bytes_current] / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),[volume_free_space_bytes_current] / 1024.0 / 1024.0)) + ' MB'
			when [volume_free_space_bytes_current] / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),[volume_free_space_bytes_current] / 1024.0 / 1024.0 / 1024.0)) + ' GB' 
			else convert(varchar(100),convert(decimal(5,2),[volume_free_space_bytes_current] / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end

	, [growth_bytes_per_day_formatted] = case
			when growth_bytes_per_day / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),growth_bytes_per_day / 1024.0 )) + ' KB / Day'
			when growth_bytes_per_day / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),growth_bytes_per_day / 1024.0 / 1024.0)) + ' MB / Day'
			when growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(5,2),growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0)) + ' GB / Day' 
			else convert(varchar(100),convert(decimal(5,2),growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end
	, [free_space_percentage_formatted] = convert(varchar(50),convert(decimal(5,0),volume_free_space_bytes_current * 1.0 / volume_total_space_bytes_current  * 100.0)) + ' %'
	from cte_volume_growth

