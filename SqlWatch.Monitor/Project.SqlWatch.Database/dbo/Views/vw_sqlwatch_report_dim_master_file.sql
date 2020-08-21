CREATE VIEW [dbo].[vw_sqlwatch_report_dim_master_file] with schemabinding
	AS 
		select db.[database_name], [d].[sqlwatch_database_id], [d].[sqlwatch_master_file_id], [d].[file_id]
		, [d].[file_type]

		, file_type_desc = [dbo].[ufn_sqlwatch_get_file_type_desc](d.file_type)
		, [d].[file_name], [d].[file_physical_name], [d].[sql_instance], [d].[date_last_seen], [d].[logical_disk], size_on_disk_bytes=isnull(lg.size_on_disk_bytes,fg.size_on_disk_bytes)

		, [size_on_disk_bytes_formatted] =  [dbo].[ufn_sqlwatch_format_bytes] (isnull(lg.size_on_disk_bytes,fg.size_on_disk_bytes))

		from [dbo].[sqlwatch_meta_master_file] d

		inner join [dbo].[sqlwatch_meta_database] db
			on db.sqlwatch_database_id = d.sqlwatch_database_id
			and db.sql_instance = d.sql_instance
			and db.is_current = 1

		-- get first and last snapshots
		left join (
				select sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id]
					, first_snapshot_time=min(snapshot_time)
					, last_snapshot_time=max(snapshot_time) 
				from [dbo].[sqlwatch_logger_perf_file_stats]
				group by sql_instance, [sqlwatch_database_id], [sqlwatch_master_file_id]
		) h
		on h.sql_instance = d.sql_instance
		and h.sqlwatch_database_id = d.sqlwatch_database_id
		and h.sqlwatch_master_file_id = d.sqlwatch_master_file_id

		-- get first snapshot data
		left join [dbo].[sqlwatch_logger_perf_file_stats] fg
		on h.sql_instance = fg.sql_instance
		and h.[sqlwatch_database_id] = fg.[sqlwatch_database_id]
		and h.[sqlwatch_master_file_id] = fg.[sqlwatch_master_file_id]
		and h.first_snapshot_time = fg.snapshot_time

		-- get last snapshot data
		left join [dbo].[sqlwatch_logger_perf_file_stats] lg
		on h.sql_instance = lg.sql_instance
		and h.[sqlwatch_database_id] = lg.[sqlwatch_database_id]
		and h.[sqlwatch_master_file_id] = lg.[sqlwatch_master_file_id]
		and h.last_snapshot_time = lg.snapshot_time