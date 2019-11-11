CREATE VIEW [dbo].[vw_sqlwatch_report_dim_database] with schemabinding
as 
	with cte_database as (
		select [database_name], [database_create_date], d.[sql_instance], d.[sqlwatch_database_id], [deleted_when] 

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

			outer apply (
				select [f].[sqlwatch_database_id], [f].[database_size_bytes], [f].[unallocated_space_bytes], [f].[reserved_bytes]
					, [f].[data_bytes], [f].[index_size_bytes], [f].[unused_bytes], [f].[log_size_total_bytes], [f].[log_size_used_bytes], [f].[snapshot_time], [f].[snapshot_type_id], [f].[sql_instance]
				, h.first_snapshot_time, h.last_snapshot_time
				from [dbo].[sqlwatch_logger_disk_utilisation_database] f
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
				and f.sqlwatch_database_id = d.sqlwatch_database_id
				) vc

			outer apply (
				select g1.[database_size_bytes], g1.snapshot_time, g1.[unallocated_space_bytes], g1.[reserved_bytes], g1.[data_bytes], g1.[log_size_total_bytes]
				from [dbo].[sqlwatch_logger_disk_utilisation_database] g1
				where g1.sql_instance = d.sql_instance
				and snapshot_time = vc.first_snapshot_time
				and g1.sqlwatch_database_id = vc.sqlwatch_database_id
				) fg

			outer apply (
				select g2.[database_size_bytes], g2.snapshot_time, g2.[unallocated_space_bytes], g2.[reserved_bytes], g2.[data_bytes], g2.[log_size_total_bytes]
					,g2.[index_size_bytes], g2.[unused_bytes]
				from [dbo].[sqlwatch_logger_disk_utilisation_database] g2
				where g2.sql_instance = d.sql_instance
				and snapshot_time = vc.last_snapshot_time
				and g2.sqlwatch_database_id = vc.sqlwatch_database_id
				) lg
	) , cte_database_growth as (
	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [deleted_when], [database_size_bytes_current], [database_bytes_growth], [total_growth_days] , [log_size_total_bytes_current], [log_size_bytes_growth]
		, database_growth_bytes_per_day = case when [total_growth_days] > 0 and [database_bytes_growth] > 0 then [database_bytes_growth] / total_growth_days else 0 end
		, log_growth_bytes_per_day = case when [total_growth_days] > 0 and [log_size_bytes_growth] > 0 then [log_size_bytes_growth] / total_growth_days else 0 end
		, data_bytes_current, index_size_bytes_current, [unused_bytes_current], unallocated_space_bytes_current
	from cte_database
	)
	select [database_name], [database_create_date], [sql_instance], [sqlwatch_database_id], [deleted_when], [database_size_bytes_current], [database_bytes_growth]
		, [total_growth_days], database_growth_bytes_per_day, log_growth_bytes_per_day, [log_size_total_bytes_current]
		, data_bytes_current, index_size_bytes_current, [unused_bytes_current], unallocated_space_bytes_current
	, [database_size_bytes_current_formatted] = case 
			when [database_size_bytes_current] / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[database_size_bytes_current] / 1024.0 )) + ' KB'
			when [database_size_bytes_current] / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[database_size_bytes_current] / 1024.0 / 1024.0)) + ' MB'
			when [database_size_bytes_current] / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[database_size_bytes_current] / 1024.0 / 1024.0 / 1024.0)) + ' GB' 
			else convert(varchar(100),convert(decimal(10,2),[database_size_bytes_current] / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end
	, [growth_bytes_per_day_formatted] = case
			when database_growth_bytes_per_day / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),database_growth_bytes_per_day / 1024.0 )) + ' KB / Day'
			when database_growth_bytes_per_day / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),database_growth_bytes_per_day / 1024.0 / 1024.0)) + ' MB / Day'
			when database_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),database_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0)) + ' GB / Day' 
			else convert(varchar(100),convert(decimal(10,2),database_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end

	, [log_size_bytes_current_formatted] = case 
			when [log_size_total_bytes_current] / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[log_size_total_bytes_current] / 1024.0 )) + ' KB'
			when [log_size_total_bytes_current] / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[log_size_total_bytes_current] / 1024.0 / 1024.0)) + ' MB'
			when [log_size_total_bytes_current] / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),[log_size_total_bytes_current] / 1024.0 / 1024.0 / 1024.0)) + ' GB' 
			else convert(varchar(100),convert(decimal(10,2),[log_size_total_bytes_current] / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end

	, [log_growth_bytes_per_day_formatted] = case
			when log_growth_bytes_per_day / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),log_growth_bytes_per_day / 1024.0 )) + ' KB / Day'
			when log_growth_bytes_per_day / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),log_growth_bytes_per_day / 1024.0 / 1024.0)) + ' MB / Day'
			when log_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),log_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0)) + ' GB / Day' 
			else convert(varchar(100),convert(decimal(10,2),log_growth_bytes_per_day / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
			end
	from cte_database_growth
